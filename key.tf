
data "aws_key_pair" "taskkp" {
  key_name           = var.key_name
  include_public_key = true
}