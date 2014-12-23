console.log 'Loading event'

AWS = require 'aws-sdk'
S3 = new AWS.S3
  apiVersion: '2006-03-01'

Crypto = require "crypto"
Q = require "q"

exports.handler = (event, context) ->
  console.log('Received event:')
  console.log(JSON.stringify(event, null, '  '))

  record = event.Records[0]

  # Get the object from the event and show its content type
  bucket = record.s3.bucket.name
  key = record.s3.object.key

  params = Bucket:bucket, Key:key

  console.log params

  Q.ninvoke(S3, "getObject", params)
  .then (data) ->
    shasum = Crypto.createHash 'sha1'

    console.log('CONTENT TYPE:', data.ContentType)

    console.log data.Body

    shasum.update data.Body

    console.log("DIGEST:", shasum.digest("hex"))

    context.done(null, '')
  , (error) ->
    console.error "Error:", error

    context.done('error', "error getting file #{error}")
