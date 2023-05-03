data "aws_ami" "ami" {
  name_regex       = "devops-practice-with-ansible"
  owners           = ["self"]

}

# Use this data source to get the access
# to the effective Account ID, User ID, and ARN in which Terraform is authorized.
data "aws_caller_identity" "account" {}
# inside this data source block we need not give any argument