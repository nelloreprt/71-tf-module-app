# step-1 we have to first create Launch Template
resource "aws_launch_template" "main" {
  name = "${var.component}-${var.env}"

  # our instances need to fetch parameters from aws_parameter_store
 // iam_instance_profile {
 //   name = "test"
 //  }

  image_id = data.aws_ami.ami.image_id

  instance_market_options {
    market_type = "spot"
  }

  instance_type = var.instance_type


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

