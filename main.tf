resource "aws_key_pair" "tf-key" {
  key_name = "tfkey"
  public_key = file("tfkey.pub")
}

resource "aws_instance" "myinstance" {
  ami           = "ami-006935d9a6773e4ec"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.sg1.id]
  subnet_id = aws_subnet.public_subnet.id
  key_name      = aws_key_pair.tf-key.key_name
  tags = {
    name = "myinstance"
  }
  connection {
    type = "ssh"
    host = self.public_ip
    user = "ec2-user"
    private_key = file("tfkey")
  }
  
  provisioner "remote-exec" {
  inline = [
    "sudo yum install mysql -y"
  ]
  }

  
  provisioner "local-exec" {
    command = "mysql -h [output.db_instance_address.value] -P 3306 -u [resource.aws_db_instance.mydb.username] -p [resource.aws_db_instnce.mydb.password] < ~/schema.sql"
    }
} 
 resource "aws_vpc" "myvpc" {
  cidr_block       = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "myvpc"
  }
}
resource "aws_internet_gateway" "myigw" {
  vpc_id = aws_vpc.myvpc.id

  tags = {
    Name = "myigw"
  }
}
# Routing tables to route traffic for Private Subnet
resource "aws_route_table" "rtdb" {
  vpc_id = aws_vpc.myvpc.id
  
  tags = {
    Name        = "rtdb"
  }
}
# Routing tables to route traffic for Public Subnet
resource "aws_route_table" "rtec2" {
  vpc_id = aws_vpc.myvpc.id

  tags = {
    Name        = "rtec2"
  }
}
# Route for Internet Gateway
resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.rtec2.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.myigw.id
}

# Route table associations for both Public & Private Subnets
resource "aws_route_table_association" "public" {
subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.rtec2.id
}

#resource "aws_route_table_association" "private1" {
#  subnet_id      = aws_subnet.private_subnet1.id
# route_table_id = aws_route_table.rtdb.id
#}

#resource "aws_route_table_association" "private2" {
# subnet_id      = aws_subnet.private_subnet2.id
 # route_table_id = aws_route_table.rtdb.id
#}



# Public subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true
  tags = {
    Name        = "public-subnet"
  }
}

# Private Subnet 1
resource "aws_subnet" "private_subnet1" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "10.0.10.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true
  tags = {
    Name        = "private-subnet1"
  }
}

# Private Subnet 2
resource "aws_subnet" "private_subnet2" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "10.0.20.0/24"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true
  tags = {
    Name        = "private-subnet2"
  }
}

resource "aws_db_subnet_group" "dbsg" {
  name       = "main"
  subnet_ids = [aws_subnet.private_subnet1.id, aws_subnet.private_subnet2.id]

  tags = {
    Name = "dbsg"
  }
}
resource "aws_security_group" "sg1" {
  name        = "sg1"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
   ingress {
    from_port        = 3306
    to_port          = 3306
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }  
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg1"
  }
}

resource "aws_security_group" "dbsg" {
  name        = "dbsg"
  vpc_id      = aws_vpc.myvpc.id
  ingress {
    from_port        = 2049
    to_port          = 2049
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    from_port        = 3306
    to_port          = 3306
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }  
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "dbsg"
  }
}
resource "aws_db_instance" "mydb" {
  allocated_storage    = 20
  db_name              = "mydatabase"
  engine               = "mysql"
  engine_version       = "8.0.33"
  instance_class       = "db.t2.micro"
  username             = "mydatabase"
  password      = "mydatabase"
 # parameter_group_name = "default"
  skip_final_snapshot  = true
  publicly_accessible  = true
  vpc_security_group_ids = [aws_security_group.dbsg.id]
  db_subnet_group_name = aws_db_subnet_group.dbsg.id
 

}