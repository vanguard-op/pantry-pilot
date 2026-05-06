module "media_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket_prefix = "pantry-pilot-media-"
  acl    = "private"

  control_object_ownership = true
  object_ownership         = "ObjectWriter"

  cors_rule = [
    {
      allowed_headers = ["*"]
      allowed_methods = ["GET", "POST", "PUT", "DELETE"]
      allowed_origins = ["*"]
      expose_headers  = []
      max_age_seconds = 3000
    }
  ]
}