provider "aws" {
 region = "ap-south-1"
 profile = "prakhar"
}


resource "aws_vpc" "main" {
  cidr_block       = "192.168.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = "true"

  tags = {
    Name = "pmbvpc"
  }
}

resource "aws_subnet" "subnet1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "192.168.0.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "pmbsubnet1"
  }
}

resource "aws_subnet" "subnet2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "192.168.1.0/24"
  availability_zone = "ap-south-1b"


  tags = {
    Name = "pmbsubnet2"
  }
}

resource "aws_internet_gateway" "gw" {
  depends_on = [
             aws_vpc.main,
     ]
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "pmb_internet_gw"
  }
}

resource "aws_route_table" "r" {
  
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "pmb_rt_for_IGW"
  }
}

resource "aws_route_table_association" "a" {
  depends_on = [ aws_subnet.subnet1, aws_route_table.r, ]
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.r.id
}


resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "mytask_key" {
  depends_on = [ tls_private_key.example, ]
  key_name   = "task2_key"
  public_key = tls_private_key.example.public_key_openssh
}

resource "aws_security_group" "task3_sec_group_wp" {
  depends_on = [ aws_vpc.main, ]
  name = "task2_sec_group_wp"
  description = "Allow SSH and HTTP protocol inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "For SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "For HTTP"
    from_port   = 80
    to_port     = 80
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
    Name = "task3_sec_group_wp"
  }
}

resource "aws_instance" "wp_instance"  {
  depends_on = [ aws_key_pair.mytask_key, aws_security_group.task3_sec_group_wp, ]
  ami = "ami-7e257211"
  instance_type = "t2.micro"
  key_name = aws_key_pair.mytask_key.key_name
  security_groups = [aws_security_group.task3_sec_group_wp.id]
  subnet_id = aws_subnet.subnet1.id

  tags = {
       Name = "wp_os"
      }
  
}



resource "aws_security_group" "task3_sec_group_mysql" {
  depends_on = [ aws_instance.wp_instance, ]
  name        = "task3_sec_group_mysql"
  description = "For MySQL"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "For MySQL"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "task3_sec_group_mysql"
  }
}


resource "aws_instance" "mysql_instance"  {
  depends_on = [ aws_key_pair.mytask_key, aws_security_group.task3_sec_group_mysql, ]
  ami = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = aws_key_pair.mytask_key.key_name
  security_groups = [aws_security_group.task3_sec_group_mysql.id]
  subnet_id = aws_subnet.subnet2.id

  tags = {
       Name = "mysql_os"
      }
  
}

resource "null_resource" "nulllocal1" {
    depends_on = [aws_instance.wp_instance, aws_instance.mysql_instance, ]

    provisioner "local-exec" {
            command = "start chrome ${aws_instance.wp_instance.public_ip}"
         }
}
