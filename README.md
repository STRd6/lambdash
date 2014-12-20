lambdash
========

Handle incoming uploads, verify SHA1 hash and publish to a public folder.

How To
------

Create a bucket for incoming uploads (`sourcebucket`)

Create a bucket for the processed uploads (`targetbucket`)

Create a lambda function to process the uploads

Add a notification trigger on the incoming bucket to invoke a lambda function

Create a CloudFront distribution to serve `targetbucket`

Host a webserver that generates user scoped policies to upload to `sourcebucket`
