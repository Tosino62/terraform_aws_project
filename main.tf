resource "aws_vpc" "myvpc" {
    cidr_block = var.cidr
}

resource "aws_subnet" "sub1" {
    vpc_id = aws_vpc.myvpc.id
    cidr_block = "10.0.0.0/24"
    availability_zone = "us-east-1a"
    map_public_ip_on_launch = true
}

resource "aws_subnet" "sub2" {
    vpc_id = aws_vpc.myvpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "us-east-1b"
    map_public_ip_on_launch = true
}


resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.myvpc.id
}

resource "aws_route_table" "RT" {
    vpc_id = aws_vpc.myvpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }
}

resource "aws_route_table_association" "rta1" {
  subnet_id         = aws_subnet.sub1.id
  route_table_id = aws_route_table.RT.id
}

resource "aws_route_table_association" "rta2" {
    subnet_id = aws_subnet.sub2.id
    route_table_id = aws_route_table.RT.id
}


resource "aws_security_group" "allow_tls" {
  name        = "websg"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.myvpc.id


  ingress {
    description = "HTTP from VPC"
    cidr_blocks =   ["0.0.0.0/0"]
    from_port   = 80
    protocol   = "tcp"
    to_port     = 80

  }

  ingress {
    description = "SSH"
    cidr_blocks =   ["0.0.0.0/0"]
    from_port   = 22
    protocol   = "tcp"
    to_port     = 22

  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]

  }

  tags = {
    Name = "Web-sg"
  }
}

resource "aws_s3_bucket" "example" {
  bucket = "toscoawsterraformproject"
}

resource "aws_s3_bucket_public_access_block" "example1" {
  bucket = aws_s3_bucket.example.id

  block_public_acls = false
  block_public_policy = false
  ignore_public_acls = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "public_policy" {
  bucket = aws_s3_bucket.example.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.example.arn}/*"
      }
    ]
  })
}

resource "aws_instance" "webserver1" {
    ami = "ami-0e1bed4f06a3b463d"
    instance_type = "t2.micro"
    vpc_security_group_ids = [aws_security_group.allow_tls.id]
    subnet_id = aws_subnet.sub1.id
  
}

resource "aws_lb" "myalb" {
  name               = "myalb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_tls.id]
  subnets            = [aws_subnet.sub1.id, aws_subnet.sub2.id]

  tags = {
    Name = "web"
  }
}

resource "aws_lb_target_group" "tg" {
  name = "myTG"
  port = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.myvpc.id


  health_check {
    path = "/"
    port = "traffic-port"  
  }  
}


resource "aws_lb_target_group_attachment" "attach1" {
    target_group_arn = aws_lb_target_group.tg.arn
    target_id = aws_instance.webserver1.id
    port = 80
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.myalb.arn
  port = 80
  protocol = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.tg.arn
    type = "forward"
  }
}

output "loadbalancerdns" {
    value = aws_lb.myalb.dns_name
  
}