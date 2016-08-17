child_process = require 'child_process'
path = require 'path'

_ = require 'lodash'
uuid = require 'uuid'
services = require('./jupyter-js-services-shim')

Kernel = require './kernel'

module.exports =
class WSKernel extends Kernel
    constructor: (kernelSpec, grammar, @session) ->
        super kernelSpec, grammar

        @session.statusChanged.connect => @_onStatusChange()
        @_onStatusChange() # Set initial status correctly

    interrupt: ->
        @session.kernel.interrupt()

    restart: ->
        @session.kernel.restart()

    _onStatusChange: ->
        @statusView.setStatus @session.status

    _execute: (code, onResults, callWatches) ->
        future = @session.kernel.execute(
            code: code
        )

        future.onIOPub = (message) =>
            if callWatches and
            message.header.msg_type is 'status' and
            message.content.execution_state is 'idle'
                @_callWatchCallbacks()

            if onResults?
                console.log 'WSKernel: _execute:', message
                result = @_parseIOMessage(message)
                if result?
                    onResults result

        future.onReply = (message) ->
            if message.content.status is 'error'
                return
            result =
                data: 'ok'
                type: 'text'
                stream: 'status'
            onResults?(result)

    execute: (code, onResults) ->
        @_execute code, onResults, true

    executeWatch: (code, onResults) ->
        @_execute code, onResults, false

    complete: (code, onResults) ->
        @session.kernel.complete
            code: code
            cursor_pos: code.length
        .then (message) ->
            onResults?(message.content)

    inspect: (code, cursor_pos, onResults) ->
        @session.kernel.inspect
            code: code
            cursor_pos: cursor_pos
            detail_level: 0
        .then (message) ->
            onResults?(
                data: message.content.data
                found: message.content.found
            )

    destroy: ->
        console.log 'WSKernel: destroying jupyter-js-services Session'
        @session.dispose()
        super
