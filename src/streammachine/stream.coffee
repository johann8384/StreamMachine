_u = require "underscore"
EventEmitter = require('events').EventEmitter

module.exports = class Stream extends EventEmitter
    @DefaultOptions:
        meta_interval:  10000
        name:           ""
        type:           null
        
    constructor: (@core,key,log,opts) ->
        @options = _u.defaults opts||{}, @DefaultOptions
            
        @log = log
        @key = key
            
        @listeners = 0

        @preroll = null
        
        @dataFunc = (chunk) => @emit "data", chunk
        @metaFunc = (chunk) => @emit "metadata", chunk
        
        # now run configure...
        @configure(opts)
                                    
        # set up a rewind buffer
        @rewind = new @core.Rewind @, opts.rewind
            
    #----------
        
    configure: (opts) ->
        # -- Source -- #
        
        # make sure our source is valid
        if @core.Sources[ opts.source?.type ]
            # stash our existing source if we have one
            old_source = @source || null
            
            # bring the new / only source up
            source = new @core.Sources[ opts.source?.type ] @, @key, opts.source
            if source.connect()
                if old_source
                    # unhook from the old source's events
                    old_source.removeListener "metadata",   @metaFunc
                    old_source.removeListener "data",       @dataFunc
                    
                @source = source
                    
                # connect to the new source's events
                source.on "metadata",   @metaFunc
                source.on "data",       @dataFunc

                # disconnect the old source, which we're now no longer using
                old_source?.disconnect()
            else
                @log.error "Failed to connect to new source"
        else
            @log.error "Invalid source type.", opts:opts
            return false
                        
        # -- Preroll -- #
        
        @log.debug "Preroll settings are ", preroll:opts.preroll
        
        @preroll.disconnect() if @preroll
        
        if opts.preroll?
            # create a Preroller connection
            @preroll = new @core.Preroller @, @key, opts.preroll
            
    #----------
        
    disconnect: ->
        # disconnect any listeners
        
            
        # disconnect the stream source
        @source?.disconnect()
        
    #----------
            
    registerListener: (listen) ->
        # increment our listener count
        @listeners += 1
        
        # keep track of when they started listening
        listen.startTime = (new Date)
                        
        # log the connection start
        @log.debug "Connection start", req:listen.req, listeners:@listeners
        
    #----------
            
    closeListener: (listen) ->
        # decrement listener count
        @listeners -= 1
        
        # compute listening duration
        seconds = null
        endTime = (new Date)
        if listen.startTime
            seconds = (endTime.getTime() - listen.startTime.getTime()) / 1000
                    
        # log the connection end
        @log.debug "Connection end", req:listen.req, listeners:@listeners, bytes:listen.req?.connection?.bytesWritten, seconds:seconds
        @log.request "", path:listen.reqPath, ip:listen.reqIP, bytes:listen.req?.connection?.bytesWritten, seconds:seconds, time:endTime, ua:listen.reqUA
