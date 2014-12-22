Set up a whole distributed uploader app
---------------------------------------

    REGION = "us-east-1"

    AWS = require "aws-sdk"
    Lambda = new AWS.Lambda
      region: REGION # TODO: Shouldn't this automatically come from config?
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
      executionRole: "#{prefix}lambda_execution"
      invocationRole: "#{prefix}lambda_invocation"
      lambda: "#{prefix}lambda-function"
      region: REGION
      account: "186123361267"

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

    roleArn = (name) ->
      "arn:aws:iam::#{config.account}:role/#{name}"

    lambdaArn = (config) ->
      "arn:aws:lambda:#{config.region}:#{config.account}:function:#{config.lambda}"

    invocationRolePolicy = (config) ->
      """
        {
          "Version": "2012-10-17",
          "Statement": [
            {
              "Effect": "Allow",
              "Action": [
                "lambda:InvokeFunction"
              ],
              "Resource": [
                "#{lambdaArn(config)}"
              ]
            }
          ]
        }
      """

    invocationAssumeRolePolicyDocument = (config) ->
      """
        {
          "Version": "2012-10-17",
          "Statement": [
            {
              "Sid": "",
              "Effect": "Allow",
              "Principal": {
                "Service": "s3.amazonaws.com"
              },
              "Action": "sts:AssumeRole",
              "Condition": {
                "StringLike": {
                  "sts:ExternalId": "arn:aws:s3:::#{config.buckets.incoming}"
                }
              }
            }
          ]
        }
    """

    executionRolePolicy = (config) ->
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

    executionAssumeRolePolicyDocument = (config) ->
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

    ensureRole = (name, assumeRolePolicyDocument, policyDocument) ->
      console.log "Checking role: #{name}"
      Q.ninvoke(IAM, 'getRole', RoleName: name)
      .fail (error) ->
        params =
          AssumeRolePolicyDocument: assumeRolePolicyDocument
          RoleName: name

        console.log "Creating role:", params

        Q.ninvoke(IAM, 'createRole', params)
      .then ({Role}) ->
        params =
          PolicyDocument: policyDocument
          PolicyName: "lambda_policy"
          RoleName: name

        console.log "Attaching role policy:", params

        Q.ninvoke(IAM, 'putRolePolicy', params)

        Role.Arn

    uploadFunction = (name) ->
      params =
        FunctionName: name
        FunctionZip: fs.readFileSync("./lambda.zip")
        Handler: "handler"
        Mode: "event"
        Role: roleArn(config.executionRole)
        Runtime: "nodejs"

      console.log "Creating lambda:", params

      Q.ninvoke(Lambda, 'uploadFunction', params)
      .then ({FunctionARN}) ->
        FunctionARN

    linkNotification = (config) ->
      params =
        Bucket: config.buckets.incoming
        NotificationConfiguration:
          CloudFunctionConfiguration:
            CloudFunction: lambda
            Event: "s3:ObjectCreated:*"
            Id: "lambda-duder"
            InvocationRole: roleArn(config.invocationRole)

      console.log "Linking: #{bucket} -> #{lambda}", params

      Q.ninvoke(S3, 'putBucketNotification', params)

Buckets
-------

We need an incoming and outgoing bucket.

    createdBuckets = Q.all([

Create a bucket for incoming uploads (`sourcebucket`)

      createBucket(config.buckets.incoming)

Create a bucket for the processed uploads (`targetbucket`)

      createBucket(config.buckets.outgoing)

    ]).then log, error

Roles
-----

We need an execution and invocation role.

    createdRoles = Q.all([

Create lambda execution role.

      ensureRole(
        config.executionRole,
        executionAssumeRolePolicyDocument(config),
        executionRolePolicy(config)
      )

Create lambda invocation role.

      ensureRole(
        config.invocationRole,
        invocationAssumeRolePolicyDocument(config),
        invocationRolePolicy(config)
      )
    ])

Create a lambda function to process the uploads.

    createdLambda = uploadFunction(config.lambda)

Add a notification trigger on the incoming bucket to invoke a lambda function

    Q.all([
      createdBuckets
      createdRoles
      createdLambda
    ]).then ([buckets, roles, lambda]) ->
      linkNotification config.buckets.incoming, lambda
    .then log, error

Create a CloudFront distribution to serve `targetbucket`

Host a webserver that generates user scoped policies to upload to `sourcebucket`
