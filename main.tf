# step-1 we have to first create Launch Template
resource "aws_launch_template" "main" {
  name = "${var.component}-${var.env}"

  # our instances need to fetch parameters from aws_parameter_store
  # SPECIAL # SPECIAL # SPECIAL # SPECIAL # SPECIAL
  # we need to connect the instance_profile created in iam.tf
  iam_instance_profile {
    name = aws_iam_instance_profile.main.name
   }

  image_id = data.aws_ami.ami.image_id

  instance_market_options {
    market_type = "spot"
  }

  instance_type = var.instance_type

  # SPECIAL # SPECIAL # SPECIAL # SPECIAL # SPECIAL
  # we need to connect the security_group created to aws_launch_template
  vpc_security_group_ids = [aws_security_group.main.id]


  # we give placements through subnets
  #placement {
  #  availability_zone = "us-west-2a"
  #}

  tag_specifications {
    resource_type = "instance"

    tags = merge(var.tags,
      { Name = "${var.component}-${var.env}" })
  }

  # the file_userdata.sh will be converted into base64_format using the function "filebase64encode"
  # " ${path.module} " >>  the file_userdata.sh will be searched in the location "71-tf-module-app"
  # " templatefile " >> is another function to replace the variables
  user_data = filebase64encode(templatefile("${path.module}/userdata.sh" , {
      component = var.component
      env       = var.env
  }) )



}

resource "aws_autoscaling_group" "bar" {
  name = "${var.component}-${var.env}"
  # availability_zones = ["us-east-1a"] >> will come from subnets
  desired_capacity   = var.desired_capacity
  max_size           = var.max_size
  min_size           = var.min_size
  vpc_zone_identifier       = var.subnets

  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"  # usually LATEST will be used, Launch Template of Auto ScalingGroup supports versioning
  }

  tag {
    key                 = "name"
    propagate_at_launch = false
    value               = "${var.component}-${var.env}"
  }
}

# we are creating this security group for the servers running in private_subnets
# so that the workstation/bastion_node will be allowed to access all the servers in private_subnets
resource "aws_security_group" "main" {
  name        = "${var.component}-${var.env}"
  description = "${var.component}-${var.env}"
  vpc_id      = var.vpc_id    # vpc_id is comming from tf-module-vpc >> output_block

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = var.bastion_cidr
  }


  # We need to open the Application port & we also need too tell to whom that port is opened
  # (i.e who is allowed to use that application port)
  # I.e shat port to open & to whom to open
  # Example for CTALOGUE we will open port 8080 ONLY WITHIN the APP_SUBNET
  # So that the following components (i.e to USER / CART / SHIPPING / PAYMENT) can use CATALOGUE.
  # And frontend also is necessarily need not be accessing the catalogue, i.e not to FRONTEND, because frontend belongs to web_subnet
  ingress {
    description      = "APP"
    from_port        = var.port
    to_port          = var.port
    protocol         = "tcp"
    cidr_blocks      = var.allow_app_to  # we want cidr number not subnet_id
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = merge(var.tags,
    { Name = "${var.component}-${var.env}-security-group" })
}
