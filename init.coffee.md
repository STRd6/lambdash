Set up a whole distributed uploader app
---------------------------------------

    AWS = require "aws-sdk"
    Lambda = new AWS.Lambda
      region: "us-east-1" # TODO: Shouldn't this automatically come from config?
    S3 = new AWS.S3()
    IAM = new AWS.IAM()

    Q = require "q"

    fs = require('fs')
    # spawn = require('child_process').spawn

    prefix = "yoloswagwat-"

    config =
      buckets:
        incoming: "#{prefix}incoming"
        outgoing: "#{prefix}outgoing"

    error = (error) ->
      console.error "Error: #{error}"

    log = (data) ->
      console.log data

    createBucket = (name) ->
      console.log "Creating bucket: #{name}"
      Q.ninvoke(S3, 'createBucket', Bucket: name)

    deleteBucket = (name) ->
      console.log "Deleting bucket: #{name}"
      Q.ninvoke(S3, 'deleteBucket', Bucket: name)

    rolePermissions = (config) ->
      """
        {
          "Version": "2012-10-17",
          "Statement": [
            {
              "Effect": "Allow",
              "Action": [
                "logs:*"
              ],
              "Resource": "arn:aws:logs:*:*:*"
            },
            {
              "Effect": "Allow",
              "Action": [
                "s3:DeleteObject",
                "s3:GetObject"
              ],
              "Resource": [
                "arn:aws:s3:::#{config.buckets.incoming}"
              ]
            },
            {
              "Effect": "Allow",
              "Action": [
                "s3:GetObject",
                "s3:PutObject"
              ],
              "Resource": [
                "arn:aws:s3:::#{config.buckets.outgoing}"
              ]
            }
          ]
        }
      """

    rolePolicy = (config) ->
      """
        {
          "Version": "2012-10-17",
          "Statement": [
            {
              "Sid": "",
              "Effect": "Allow",
              "Principal": {
                "Service": "lambda.amazonaws.com"
              },
              "Action": "sts:AssumeRole"
            }
          ]
        }
      """

    ensureRole = (name) ->
      console.log "Checking role: #{name}"
      Q.ninvoke(IAM, 'getRole', RoleName: name)
      .fail (error) ->
        params =
          AssumeRolePolicyDocument: rolePolicy(config)
          RoleName: name

        console.log "Creating role:", params

        Q.ninvoke(IAM, 'createRole', params)
      .then ->
        params =
          PolicyDocument: rolePermissions(config)
          PolicyName: "lambda_policy"
          RoleName: name

        console.log "Attaching role policy:", params

        Q.ninvoke(IAM, 'putRolePolicy', params)

    uploadFunction = (name, role) ->
      params =
        FunctionName: name
        FunctionZip: fs.readFileSync("./lambda.zip")
        Handler: "handler"
        Mode: "event"
        Role: role
        Runtime: "nodejs"

      console.log "Creating lambda:", params

      Q.ninvoke(Lambda, 'uploadFunction', params)

    linkNotification = (bucket, lambda) ->
      console.log "Linking: #{bucket} -> #{lambda}"

      params =
        Bucket: bucket
        NotificationConfiguration:
          CloudFunctionConfiguration:
            CloudFunction: null # TODO
            Events: [
              's3:ObjectCreated:Put | s3:ObjectCreated:Post | s3:ObjectCreated:Copy | s3:ObjectCreated:CompleteMultipartUpload'
            ]
            Id: null # TODO
            InvocationRole: null # TODO

      Q.ninvoke(S3, 'putBucketNotification', params)

    Q.all([

Create a bucket for incoming uploads (`sourcebucket`)

      createBucket(config.buckets.incoming)

Create a bucket for the processed uploads (`targetbucket`)

      createBucket(config.buckets.outgoing)

    ]).then log, error

Create lambda role.

    ensureRole("#{prefix}lambdarole")
    .then log, error

Create a lambda function to process the uploads.

    uploadFunction("lambdoodle", "arn:aws:iam::186123361267:role/yoloswagwat-lambdarole")
    .then log, error

Add a notification trigger on the incoming bucket to invoke a lambda function



Create a CloudFront distribution to serve `targetbucket`

Host a webserver that generates user scoped policies to upload to `sourcebucket`
