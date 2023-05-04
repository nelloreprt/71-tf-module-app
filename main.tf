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

  # attaching target group to Auto_Scaling_Group
  target_group_arns = [aws_lb_target_group.main.arn]
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

# creating Target Group
resource "aws_lb_target_group" "main" {
  name     = "${var.component}-${var.env}-lb-tg"
  port     = var.port
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  health_check {
    enabled = true
    healthy_threshold = 2
    unhealthy_threshold = 5
    interval = 5
    timeout = 4
  }
  tags = merge(var.tags,
    { Name = "${var.component}-${var.env}-lb-tg" })
}

resource "aws_route53_record" "main" {
  zone_id = data.aws_route53_zone.domain.zone_id  # input >> dns_domain = "nellore.online"
  name    = local.dns_name
  type    = "CNAME"
  ttl     = 30
  records = [var.alb_dns_domain]  # input >> alb = "public"
}

resource "aws_lb_listener_rule" "listener_rule" {
  listener_arn = var.listener_arn # from output >> module.alb

  priority     = var.listener_priority   # order of listener >> from input "listener_priority = 10"
  # to process the order of listener_RULES in order one after the other based on Listener_Priority_number
  # same Listener_Priority_number can be alloted to Public_LB & Private_LB
  # Listener_Priority_number order does not matter for us

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  # any request is coming from cart-dev-nellore.online >> action is : forward to target_group >> target_group_arn = aws_lb_target_group.main.arn
  condition {
    host_header {
      values = ["local.dns_name"]   # dns_name
    }
  }
}