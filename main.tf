resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "${var.vpc_name}-vpc"
  }
}

resource "aws_subnet" "public" {
  count             = length(var.public_subnets)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnets[count.index]
  availability_zone = var.availability_zones[count.index]
  tags = {
    Name = "${var.vpc_name}-public-subnet-${count.index + 1}"
  }
}

# Create Private Subnets
resource "aws_subnet" "private" {
  count             = length(var.private_subnets)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = var.availability_zones[count.index]
  tags = {
    Name = "${var.vpc_name}-private-subnet-${count.index + 1}"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.vpc_name}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.vpc_name}-public-rt"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.vpc_name}-private-rt"
  }
}

resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  count          = length(var.public_subnets)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(var.private_subnets)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}


resource "aws_security_group" "app_security_group" {
  vpc_id      = aws_vpc.main.id
  name        = "${var.vpc_name}-app-sg"
  description = "Allow SSH and app traffic from ALB"

  dynamic "ingress" {
    for_each = var.allowed_ports
    content {
      from_port       = ingress.value
      to_port         = ingress.value
      protocol        = "tcp"
      security_groups = [aws_security_group.alb_security_group.id]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "random_uuid" "bucket_suffix" {}

resource "aws_s3_bucket" "bucket" {
  bucket        = "csye6225-${random_uuid.bucket_suffix.result}"
  force_destroy = true # Enable force destroy to allow Terraform to delete non-empty buckets

  tags = {
    Name = "csye6225-private-bucket"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "bucket_sse" {
  bucket = aws_s3_bucket.bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = var.bucket_sse_algorithm
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "bucket_lifecycle" {
  bucket = aws_s3_bucket.bucket.id

  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    transition {
      days          = var.bucket_Transition_days
      storage_class = "STANDARD_IA"
    }
  }
}

resource "aws_security_group" "db_security_group" {
  vpc_id      = aws_vpc.main.id
  name        = "${var.vpc_name}-db-sg"
  description = "Allow DB traffic from app security group"

  ingress {
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.app_security_group.id] # Source is app SG
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.vpc_name}-db-sg"
  }
}

resource "aws_db_parameter_group" "db_parameter_group" {
  name        = "${var.vpc_name}-db-pg"
  family      = var.db_family
  description = "DB parameter group for ${var.vpc_name}"

  tags = {
    Name = "${var.vpc_name}-db-pg"
  }
}

resource "aws_db_subnet_group" "private" {
  name       = "csye6225-private-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "csye6225-private-subnet-group"
  }
}

resource "aws_db_instance" "main" {
  identifier             = "csye6225"
  engine                 = "postgres"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  username               = var.db_username
  password               = var.db_password
  db_name                = var.db_name
  multi_az               = false
  publicly_accessible    = false
  vpc_security_group_ids = [aws_security_group.db_security_group.id]
  db_subnet_group_name   = aws_db_subnet_group.private.name
  parameter_group_name   = aws_db_parameter_group.db_parameter_group.name
  skip_final_snapshot    = true # For testing; set to false in production with a snapshot identifier

  tags = {
    Name = "csye6225-rds"
  }
}

# IAM Role and Policy for EC2 to Access S3
resource "aws_iam_role" "ec2_s3_role" {
  name = "ec2-s3-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "s3_access_policy" {
  name        = "s3-access-policy"
  description = "Allow EC2 to access S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.bucket.arn,
          "${aws_s3_bucket.bucket.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_access_attach" {
  role       = aws_iam_role.ec2_s3_role.name
  policy_arn = aws_iam_policy.s3_access_policy.arn
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent_policy" {
  role       = aws_iam_role.ec2_s3_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-s3-profile"
  role = aws_iam_role.ec2_s3_role.name
}

resource "aws_cloudwatch_log_group" "webapp_logs" {
  name              = "WebAppLogs"
  retention_in_days = 7
}

resource "aws_security_group" "alb_security_group" {
  vpc_id      = aws_vpc.main.id
  name        = "${var.vpc_name}-alb-sg"
  description = "Allow HTTP and HTTPS traffic from anywhere"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.vpc_name}-alb-sg"
  }
}

resource "aws_launch_template" "csye6225_lt" {
  name_prefix   = "csye6225-lt-"
  image_id      = var.custom_ami_id
  instance_type = "t2.micro"
  key_name      = var.key_name

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.app_security_group.id]
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo "CLOUD_DATABASE_URL=postgres://${var.db_username}:${var.db_password}@${aws_db_instance.main.endpoint}/${var.db_name}" >> /opt/csye6225/webapp/.env
    echo "S3_BUCKET=${aws_s3_bucket.bucket.bucket}" >> /opt/csye6225/webapp/.env
    echo "AWS_REGION=${var.aws_region}" >> /opt/csye6225/webapp/.env
    sudo sed -i 's/development/cloud/g' /opt/csye6225/webapp/.env

    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    sudo sed -i "s/{instance_id}/$INSTANCE_ID/" /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
    sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

    sudo systemctl restart app.service
    EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "App EC2 Instance"
    }
  }
}

resource "aws_autoscaling_group" "csye6225_asg" {
  name                = "csye6225-asg"
  vpc_zone_identifier = aws_subnet.public[*].id
  target_group_arns   = [aws_lb_target_group.app_tg.arn]
  health_check_type   = "ELB"
  min_size            = 3
  max_size            = 5
  desired_capacity    = 3
  default_cooldown    = 60

  launch_template {
    id      = aws_launch_template.csye6225_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "App EC2 Instance"
    propagate_at_launch = true
  }
}

resource "aws_lb" "app_lb" {
  name               = "${var.vpc_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_security_group.id]
  subnets            = aws_subnet.public[*].id

  tags = {
    Name = "${var.vpc_name}-alb"
  }
}

resource "aws_lb_target_group" "app_tg" {
  name     = "${var.vpc_name}-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/healthz"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.vpc_name}-tg"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

resource "aws_autoscaling_policy" "scale_up" {
  name                   = "scale-up"
  policy_type            = "SimpleScaling"
  autoscaling_group_name = aws_autoscaling_group.csye6225_asg.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "cpu-utilization-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = var.scale_up_cpu_threshold
  alarm_description   = "Scale up if CPU > 5%"
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.csye6225_asg.name
  }
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "scale-down"
  policy_type            = "SimpleScaling"
  autoscaling_group_name = aws_autoscaling_group.csye6225_asg.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 300
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "cpu-utilization-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = var.scale_down_cpu_threshold
  alarm_description   = "Scale down if CPU < 3%"
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.csye6225_asg.name
  }
}

resource "aws_route53_record" "a_record" {
  zone_id = var.a_record_hosted_zone_id
  name    = var.a_record_name
  type    = "A"

  alias {
    name                   = aws_lb.app_lb.dns_name
    zone_id                = aws_lb.app_lb.zone_id
    evaluate_target_health = true
  }
}