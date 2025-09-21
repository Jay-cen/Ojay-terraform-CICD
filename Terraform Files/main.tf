############################################
# Public Subnet + Route table to IGW
############################################
resource "aws_subnet" "public_10_0_3" {
  vpc_id                  = var.vpc_id
  cidr_block              = var.subnet_cidr_block
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = { Name = "oiseoje-subnet" }
}

resource "aws_route_table" "public_rt" {
  vpc_id = var.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = var.internet_gateway_id
  }

  tags = { Name = "oiseoje-public-rt" }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_10_0_3.id
  route_table_id = aws_route_table.public_rt.id
}

############################################
# Security Group (SSH 22 + Web on var.web_port)
############################################
resource "aws_security_group" "web_sg" {
  name        = "oiseoje-web-sg"
  description = "Allow SSH and web on custom port"
  vpc_id      = var.vpc_id

  ingress {
    description = "Web"
    from_port   = var.web_port
    to_port     = var.web_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "oiseoje-web-sg" }
}

############################################
# EC2 key pair (uses your public key)
############################################
resource "aws_key_pair" "oiseoje-key" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)
}

############################################
# Ubuntu 22.04 AMI lookup (Canonical) in this region
############################################
data "aws_ami" "ubuntu_jammy" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

############################################
# Cloud-init: install Nginx, bind to var.web_port,
# create deploy user with same SSH key as ubuntu
############################################
locals {
  user_data = <<-EOF
    #!/bin/bash
    set -eux

    apt-get update -y
    DEBIAN_FRONTEND=noninteractive apt-get install -y nginx

    # Create deploy user
    id ${var.deploy_user} || useradd -m -s /bin/bash ${var.deploy_user}
    mkdir -p /home/${var.deploy_user}/.ssh
    chmod 700 /home/${var.deploy_user}/.ssh
    if [ -f /home/ubuntu/.ssh/authorized_keys ]; then
      cat /home/ubuntu/.ssh/authorized_keys >> /home/${var.deploy_user}/.ssh/authorized_keys
    fi
    chown -R ${var.deploy_user}:${var.deploy_user} /home/${var.deploy_user}/.ssh
    chmod 600 /home/${var.deploy_user}/.ssh/authorized_keys

    # Prepare web root
    mkdir -p /var/www/html
    chown -R www-data:www-data /var/www/html
    chmod -R 755 /var/www/html

    # Placeholder page (pipeline will overwrite)
    cat >/var/www/html/index.html <<'EOT'
    <!doctype html>
    <html><head><meta charset="utf-8"><title>It works!</title></head>
    <body style="font-family:sans-serif">
      <h1>Nginx on custom port</h1>
      <p>Push to GitHub to replace this page.</p>
    </body></html>
    EOT

    # Write Nginx site listening on ${var.web_port}
    cat >/etc/nginx/sites-available/lab <<'NGX'
    server {
      listen ${var.web_port} default_server;
      listen [::]:${var.web_port} default_server;

      server_name _;

      root /var/www/html;
      index index.html;

      location / {
        try_files $uri $uri/ =404;
      }
    }
    NGX

    # Enable our site, disable default
    rm -f /etc/nginx/sites-enabled/default || true
    ln -sf /etc/nginx/sites-available/lab /etc/nginx/sites-enabled/lab

    nginx -t
    systemctl enable nginx
    systemctl restart nginx
  EOF
}

############################################
# EC2 instance (Ubuntu t3.micro)
############################################
resource "aws_instance" "oiseoje-web-server" {
  ami                         = data.aws_ami.ubuntu_jammy.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public_10_0_3.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.oiseoje-key.key_name
  user_data                   = local.user_data

  tags = { Name = "oiseoje-lab-ubuntu-web" }
}
