/*
* jQuery Web Sockets Plugin v0.0.1
* http://code.google.com/p/jquery-websocket/
*
* This document is licensed as free software under the terms of the
* MIT License: http://www.opensource.org/licenses/mit-license.php
*
* Copyright (c) 2010 by shootaroo (Shotaro Tsubouchi).
*/
(function ($) {
    $.extend({
        websocketSettings: {
            open: function () { },
            close: function () { },
            message: function () { },
            options: {},
            events: {}
        },
        websocket: function (url, protocol, s) {
            var ws = WebSocket ? new WebSocket(url, protocol) : {
                send: function (m) { return false },
                close: function () { }
            };
            ws._settings = $.extend($.websocketSettings, s);
            $(ws)
			.bind('open', $.websocketSettings.open)
			.bind('close', $.websocketSettings.close)
			.bind('message', $.websocketSettings.message)
			.bind('message', function (e) {
			    var m = $.evalJSON(e.originalEvent.data);
			    var h = $.websocketSettings.events[m.command];
			    if (h) h.call(this, m);
			});
            ws._send = ws.send;
            ws.send = function (type, data) {
                var m = { command: type };
                m = $.extend(true, m, $.extend(true, {}, $.websocketSettings.options, m));
                if (data) m['data'] = data;
                try {
                    this._send($.toJSON(m));
                }
                catch (ex) {
                    alert(ex);
                    return false;
                }
                return true;
            }
            $(window).unload(function () { ws.close(); ws = null });
            return ws;
        }
    });
})(jQuery);
