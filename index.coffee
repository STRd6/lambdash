console.log 'Loading event'
aws = require 'aws-sdk'
s3 = new aws.S3
  apiVersion: '2006-03-01'

crypto = require "crypto"

shasum = crypto.createHash 'sha1'
shasum.update "hello"
console.log shasum.digest 'hex'

exports.handler = (event, context) ->
  console.log('Received event:')
  console.log(JSON.stringify(event, null, '  '))

  # Get the object from the event and show its content type
  bucket = event.Records[0].s3.bucket.name
  key = event.Records[0].s3.object.key
  s3.getObject {Bucket:bucket, Key:key},
    (err,data) ->
      if err
        console.log('error getting object ' + key + ' from bucket ' + bucket +
             '. Make sure they exist and your bucket is in the same region as this function.')
        context.done('error','error getting file'+err)
      else
        console.log('CONTENT TYPE:',data.ContentType)
        context.done(null,'');
