data "aws_ami" "ami" {
  name_regex       = "devops-practice-with-ansible"
  owners           = ["self"]

}