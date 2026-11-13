terraform {
  backend "s3" {}   # values come from -backend-config files (backends can't use variables)
}
