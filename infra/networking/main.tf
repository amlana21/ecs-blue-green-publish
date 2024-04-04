data "aws_availability_zones" "available_zones" {
  state = "available"
}

resource "aws_vpc" "bgvpc" {
  cidr_block = "10.1.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "bgvpc"
  }
}

resource "aws_internet_gateway" "bg_gw" {
  vpc_id = resource.aws_vpc.bgvpc.id

  tags = {
    Name = "bg_gw"
  }

}



resource "aws_route_table" "bg_rt_public" {
  vpc_id = resource.aws_vpc.bgvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = resource.aws_internet_gateway.bg_gw.id
  }

  tags = {
    Name = "bg_rt_public"
  }
}

resource "aws_subnet" "bg_public" {
  count                   = 2
  cidr_block              = cidrsubnet(aws_vpc.bgvpc.cidr_block, 8, 2 + count.index)
  availability_zone       = data.aws_availability_zones.available_zones.names[count.index]
  vpc_id                  = aws_vpc.bgvpc.id
  map_public_ip_on_launch = true
  tags = {
    Name = "bg_public_subnet"
  }
}

resource "aws_subnet" "bg_private" {
  count             = 2
  cidr_block        = cidrsubnet(aws_vpc.bgvpc.cidr_block, 8, count.index)
  availability_zone = data.aws_availability_zones.available_zones.names[count.index]
  vpc_id            = aws_vpc.bgvpc.id
  tags = {
    Name = "bg_private_subnet"
  }
}

resource "aws_route_table_association" "bg_public_subnet_assoc" {
  count          = 2
  subnet_id      = element(aws_subnet.bg_public.*.id, count.index)
  route_table_id = element(aws_route_table.bg_rt_public.*.id, count.index)
}




resource "aws_eip" "bg_gateway" {
  count      = 2
  vpc        = true
  depends_on = [aws_internet_gateway.bg_gw]
}

resource "aws_nat_gateway" "bg_nat_gateway" {
  count         = 2
  subnet_id     = element(aws_subnet.bg_public.*.id, count.index)
  allocation_id = element(aws_eip.bg_gateway.*.id, count.index)
}

resource "aws_route_table" "bg_private" {
  count  = 2
  vpc_id = aws_vpc.bgvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = element(aws_nat_gateway.bg_nat_gateway.*.id, count.index)
  }
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = element(aws_subnet.bg_private.*.id, count.index)
  route_table_id = element(aws_route_table.bg_private.*.id, count.index)
}


resource "aws_security_group" "bg_lb_sg" {
  name        = "bg_lb_sg"
  description = "sg for bg app lb"
  vpc_id      = resource.aws_vpc.bgvpc.id

  ingress {
    protocol   = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    from_port  = 22
    to_port    = 22
  }

  ingress {
    protocol   = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    from_port  = 80
    to_port    = 80
  }

  ingress {
    protocol   = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    from_port  = 8080
    to_port    = 8080
  }

  ingress {
    protocol   = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    from_port  = 443
    to_port    = 443
  }

  ingress {
    protocol   = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    from_port  = 3000
    to_port    = 3000
  }

  ingress {
    protocol   = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    from_port  = 5000
    to_port    = 5000
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "bg_lb_sg"
  }
}

resource "aws_lb" "bg_lb" {
  name            = "bg-lb"
  subnets         = aws_subnet.bg_public.*.id
  security_groups = [aws_security_group.bg_lb_sg.id]
}


resource "aws_lb_listener" "bg_lb_listener_blue" {
  load_balancer_arn = aws_lb.bg_lb.id
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.bg_lb_tg_blue.id
    type             = "forward"
  }
}

resource "aws_lb_listener" "bg_lb_listener_green" {
  load_balancer_arn = aws_lb.bg_lb.id
  port              = "8080"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.bg_lb_tg_green.id
    type             = "forward"
  }
}


resource "aws_lb_target_group" "bg_lb_tg_blue" {
  name        = "bg-lb-target-group-blue"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.bgvpc.id
  target_type = "ip"
  health_check {
    enabled             = true
    interval            = 30
    path                = "/"
    port                = 80
    protocol            = "HTTP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    matcher             = "200,302"
  }
}



resource "aws_lb_target_group" "bg_lb_tg_green" {
  name        = "bg-lb-target-group-green"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.bgvpc.id
  target_type = "ip"
  health_check {
    enabled             = true
    interval            = 30
    path                = "/"
    port                = 80
    protocol            = "HTTP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    matcher             = "200,302"
  }
}









resource "aws_security_group" "bg_ecs_task_sg" {
  name        = "bg_ecs_task_sg"
  vpc_id      = aws_vpc.bgvpc.id

  ingress {
    protocol        = "tcp"
    from_port       = 3000
    to_port         = 3000
    security_groups = [aws_security_group.bg_lb_sg.id]
  }
  ingress {
    protocol        = "tcp"
    from_port       = 5000
    to_port         = 5000
    security_groups = [aws_security_group.bg_lb_sg.id]
  }
  ingress {
    protocol        = "tcp"
    from_port       = 80
    to_port         = 80
    security_groups = [aws_security_group.bg_lb_sg.id]
  }
  ingress {
    protocol        = "tcp"
    from_port       = 8080
    to_port         = 8080
    security_groups = [aws_security_group.bg_lb_sg.id]
  }


  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}