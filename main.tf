#bastion server

resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public1.id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  key_name               = var.key_name
  availability_zone      = data.aws_availability_zones.az.names[0]
}
#web private server

resource "aws_instance" "private" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private1.id
  vpc_security_group_ids = [aws_security_group.sg.id]
  availability_zone      = data.aws_availability_zones.az.names[0]
  key_name               =  var.key_name
  user_data              = <<-EOL
  #!/bin/sh

  sudo apt update -y
  sudo apt install openjdk-11-jdk -y
  sudo apt-get install tomcat9 tomcat9-docs tomcat9-admin -y
  sudo cp -r /usr/share/tomcat9-admin/* /var/lib/tomcat9/webapps/ -v
  udo chmod 777 /var/lib/tomcat9/conf/tomcat-users.xml
  sudo cat <<EOF >> /var/lib/tomcat9/conf/tomcat-users.xml
  <role rolename="manager-script"/>
  <user username="tomcat" password="password" roles="manager-script"/>
  <role rolename="admin-gui"/>
  <role rolename="manager-gui"/>
  <user username="admin" password="admin" roles="admin-gui,manager-gui"/>
  </tomcat-users>
  EOF
  sudo sed -i '44d' /var/lib/tomcat9/conf/tomcat-users.xml
  echo 'clearing screen...' && sleep 5
  clear
  echo 'tomcat is installed'
  sudo systemctl restart tomcat9
  EOL
  depends_on             = [aws_nat_gateway.nat]
}



# Target Group 

resource "aws_lb_target_group" "tg1" {
  name_prefix = "tg1-"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"
  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 60
    matcher             = 200
    port                = 8080
    protocol            = "HTTP"
    path                = "/"
    timeout             = 2
  }

  tags = {
    Env = "${var.Task}-tg1"
  }

}



# Application LoadBalancer

resource "aws_lb" "alb" {
  name               = "${var.Task}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = [aws_subnet.public1.id, aws_subnet.public2.id]

  enable_deletion_protection = false

  tags = {
    Name = "${var.Task}-alb"
  }
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"
  depends_on        = [aws_lb_target_group.tg1]

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg1.arn
  }
}

# ALB Host Routing Rule -1

resource "aws_lb_listener_rule" "host_based_weighted_routing-1" {
  listener_arn = aws_lb_listener.front_end.arn
  priority     = 40

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg1.arn
  }

  condition {
    host_header {
      values = [var.domain]
    }
  }
}

resource "aws_lb_target_group_attachment" "ec2_attach" {
  target_group_arn = aws_lb_target_group.tg1.arn
  target_id        = aws_instance.private.id
}

