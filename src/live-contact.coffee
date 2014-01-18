(($) ->
    $.fn.center = -> @each ->
        e = $(this)
        e.css(position: "absolute")
        e.css
            left: "50%"
            top: "50%"
            margin: "-#{e.innerHeight()/2}px 0 0 -#{e.innerWidth()/2}px"
)(jQuery)

escapeHTML = (text) -> $("<div/>").text(text).html()

always_return = (r, f) -> ->
    try
        f.apply(null, arguments)
    catch e
        console.error e
    return r


alert = (msg, classes='', parent=document.documentElement) ->
    $("<div class='alert #{classes}'>").append(msg).appendTo(parent).center()

info = (msg, args...) -> alert(msg, 'alert-info', args...)


window.LiveContact = (options) -> (->

    @createUI = =>
        @container.empty()
        @main_div = $('<div class="live-contact-main" />').appendTo(@container)

        @top_bar = $('<div class="live-contact-top-bar" />').appendTo(@main_div)
        @top_bar_status = $('<span />').appendTo(@top_bar)
        $('<span class="label label-info" />')
            .append('<i class="glyphicon glyphicon-user" /> '+escapeHTML(@dest_nick))
            .appendTo(@top_bar_status)
        @dest_status = $('<span> is currently </span>').appendTo(@top_bar_status)
        @dest_status_label = $('<span class="live-contact-status label" />').appendTo(@dest_status)
        @disconnect_btn = $('<button class="btn btn-default btn-sm pull-right">Disconnect</button>').click(@disconnect).appendTo(@top_bar)

        @messages = $('<div class="live-contact-messages" />').appendTo(@main_div)

        @connect_modal = $('<div class="modal-content" />').appendTo(@main_div)
        @connect_form = $('<form class="form-inline" />').submit(@connect).appendTo(@connect_modal)
        form_group = $('<div class="form-group" />').appendTo(@connect_form)
        $('<label class="sr-only">Nickname</label>').appendTo(form_group)
        @nick_input = $('<input class="form-control" type="text" placeholder="Nickname" required />').appendTo(form_group)
        @connect_form.append(' ').append $('<button type="submit" class="btn btn-primary">Connect</button>')
        @connect_modal.css(width: 'auto').center()

        @connecting = info('Connecting…', @main_div)

        @msg_form = $('<form />').submit(@send_message).appendTo(@container)
        @msg_input = $('<input class="form-control" type="text" placeholder="Enter your message here" />').appendTo(@msg_form)

        @on_disconnected()

    @connect = always_return false, =>
        @from_nick = @nick_input.val()
        @connect_modal.hide().find('input').attr('disabled', '')
        @connecting.show()
        @conn.reset()
        @conn.connect @jid+'/'+@from_nick, @password, @connect_callback

    @connect_callback = (status) =>
        switch status
            when Strophe.Status.AUTHFAIL
                @on_disconnected 'The authentication failed'
            when Strophe.Status.CONNECTED
                @on_connected 'You are now connected as '+@color_nick(@from_nick)+
                              ', and your messages will be sent to '+@color_nick(@dest_nick)
            when Strophe.Status.CONNFAIL
                @on_disconnected 'The connection failed'
            when Strophe.Status.DISCONNECTED
                @on_disconnected 'You are now disconnected'
            else
                @log('ignoring strophe status '+status)

    @on_connected = (msg) =>
        @conn.addHandler @on_chat_message, null, 'message', 'chat'
        @conn.addHandler @on_error_message, null, 'message', 'error', null, @dest_addr, matchBare: true
        @conn.addHandler @on_presence, null, 'presence', null, null, @dest_addr, matchBare: true
        @conn.send $pres()
        @conn.send $msg(to: @dest_addr)
        @messages.removeClass('muted')
        @connecting.hide()
        @top_bar.show()
        @disconnect_btn.show()
        @msg_input.show()
        @add_log_message(msg, 'success') if msg

    @disconnect = =>
        @conn.sync = true
        @conn.disconnect()
        @conn.flush()
        @conn.sync = false
        return undefined

    @on_disconnected = (msg) =>
        @messages.addClass('muted')
        @connecting.hide()
        @top_bar.hide()
        @disconnect_btn.hide()
        @msg_input.hide()
        @connect_modal.show().find('input').attr('disabled', null)
        @change_dest_status ''
        @add_log_message(msg, 'error') if msg

    @on_chat_message = always_return true, (stanza) =>
        body = stanza.getElementsByTagName('body')
        if not body.length
            return @log 'received message with no body'
        msg = $(body[0]).text()
        from = stanza.getAttribute('from')
        if Strophe.getBareJidFromJid(from) == @dest_addr
            nick = @dest_nick
        else if from == @conn.jid
            nick = @from_nick
        else
            return @log 'ignoring message from unknown sender: '+from
        @add_user_message(msg, nick)

    @on_error_message = always_return true, (stanza) =>
        error = $(stanza).children('error')
        switch error.attr('type')
            when 'auth'
                @add_log_message escapeHTML("You are not authorized to send a message to #{@dest_nick}"), 'error'
                @disconnect()
            when 'cancel'
                @add_log_message escapeHTML("It seems that the user account you are trying to reach (#{@dest_addr}) does not exist"), 'error'
                @disconnect()
            when 'continue'
                return
            when 'modify'
                @add_log_message "The message was rejected, it needs to be corrected and sent again", 'error'
            when 'wait'
                @add_log_message "A temporary error occured, please try again later", 'error'
            else
                @add_log_message "An unknown error occured", 'error'
                @disconnect()

    @add_message = (msg) =>
        time = new Date().toLocaleTimeString()
        $("<p class='live-contact-message'>[#{time}] </p>")
            .append(msg)
            .appendTo(@messages)

    @add_log_message = (msg, classes) ->
        @add_message("<span class='#{classes}'>#{msg}</span>")

    @add_user_message = (msg, nick) ->
        @add_message(@color_nick(nick, ': ')+"<span>#{escapeHTML(msg)}</span>")

    @color_nick = (nick, suffix='') ->
        cls = if nick == @from_nick then 'nick1' else 'nick2'
        return "<span class='#{cls}'>#{escapeHTML(nick)}#{suffix}</span>"

    @send_message = always_return false, =>
        msg = @msg_input.val()
        @msg_input.val(null)
        if msg
            stanza = $msg(
                from: @conn.jid
                to: @dest_addr
                type: 'chat'
                xmlns: Strophe.NS.CLIENT
            ).c('body'
            ).t(msg)
            @conn.send stanza
            @on_chat_message stanza.tree()

    @on_presence = always_return true, (stanza) =>
        type = stanza.getAttribute('type')
        if type == 'unavailable'
            return @change_dest_status 'not connected'
        show = $(stanza).children('show').text()
        switch show
            when 'away', 'xa'
                @change_dest_status 'away'
            when 'dnd'
                @change_dest_status 'busy'
            else
                @change_dest_status 'connected'

    @change_dest_status = (status) =>
        return @dest_status.hide() unless status
        @dest_status.show()
        @dest_status_label.removeClass(@dest_status_class)
        @dest_status_class = status.replace(/\W/g, '-')
        @dest_status_label.addClass(@dest_status_class).text(status)

    # Init
    @bosh_url = '/http-bind'
    $.extend this, options
    @dest_nick = @dest_addr.split("@")[0] unless @dest_nick
    if not @container.length
        return console.error('LiveContact container not found')
    @log = console.log
    @conn = new Strophe.Connection(@bosh_url)
    $(window).on 'beforeunload', @disconnect
    @createUI()
    return this

).call({})
