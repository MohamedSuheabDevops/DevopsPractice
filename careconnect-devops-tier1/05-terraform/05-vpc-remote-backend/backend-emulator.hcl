bucket         = "careconnect-tfstate-demo"
key            = "vpc/dev/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "careconnect-tf-locks"
encrypt        = true

# emulator settings (CHECK the Floci port)
endpoints = {
  s3       = "http://localhost:4566"
  dynamodb = "http://localhost:4566"
}
use_path_style              = true
skip_credentials_validation = true
skip_metadata_api_check     = true
skip_requesting_account_id  = true
access_key                  = "test"
secret_key                  = "test"
