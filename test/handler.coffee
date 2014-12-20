data = require "./sample"

{handler} = require "../index"

console.log data, handler

describe "handler", ->
  it "should handle data", (done) ->
    handler data,
      done: (error, message) ->
        done()
