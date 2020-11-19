provider "aws" {
  region = "us-east-1"
  access_key = "************"
  secret_key = "************"
}

resource "aws_key_pair" "terraform_ec2_key" {
  key_name = "terraform_ec2_key"
  public_key = "${file("terraform_ec2_key.pub")}"
}


resource "aws_security_group" "vpc-security-group" {
  name        = "vpc-security-group"
  description = "Allow TLS inbound traffic"
  vpc_id      = "vpc-e625e19b"

 ingress {
    description = "SSH Rule"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  ingress {
    description = "HTTP Rule"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

 egress {
	from_port  =  0
	to_port   =  0
	protocol   =   "-1"
	cidr_blocks =  [ "0.0.0.0/0" ]
	
}
 
  tags = {
    Name = "vpc-security-group"
    Description = "My VPC Security Group"
  }
}

resource "aws_instance" "web" {
    depends_on = [
    aws_security_group.vpc-security-group,
  ]
  ami             = "ami-04bf6dcdc9ab498ca"
  instance_type   = "t2.micro"
  key_name        = "terraform_ec2_key"
  security_groups = ["vpc-security-group"]


  
connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("/home/abhay/Desktop/aws/terraform_ec2_key")
    host     = aws_instance.web.public_ip
}
provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }
  tags = {
    Name = "os1"
  }
}
resource "aws_efs_file_system" "newefs" {
  creation_token = "first"

  tags = {
    Name = "MyEFS"
  }
}




resource "aws_efs_mount_target" "alpha" {
  file_system_id =  aws_efs_file_system.newefs.id
  subnet_id      =  "subnet-cce05493"
}
resource "null_resource" "nulllocal2"  {
        provisioner "local-exec" {
            command = "git clone https://github.com/Abhay3008/facebook-data.git"
        }
}

variable "mime_types" {
  default = {
    htm = "text/html"
    html = "text/html"
    css = "text/css"
    js = "application/javascript"
    map = "application/javascript"
    json = "application/json"
    png = "image/png"
  }
}

resource "aws_s3_bucket" "terra-bucket" {
 depends_on = [ null_resource.nulllocal2
]
bucket = "git-code-for-terra67"
  acl    = "public-read"
}
resource "aws_s3_bucket_object" "push_bucket" {
depends_on = [ aws_s3_bucket.terra-bucket
]
   for_each = fileset("/tera/facebook-data/data", "**/*.*")
   bucket = aws_s3_bucket.terra-bucket.bucket
   key = replace(each.value, "/tera/facebook-data/data", "")
   source = "/tera/facebook-data/data/${each.value}"
   acl = "public-read"
   etag = filemd5("/tera/facebook-data/data/${each.value}")
   content_type = lookup(var.mime_types, split(".", each.value)[1])
}

resource "aws_cloudfront_distribution" "s3-web-distribution" {
  origin {
    domain_name = "git-code-for-terra67.s3.amazonaws.com"
    origin_id   = aws_s3_bucket.terra-bucket.id
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_s3_bucket.terra-bucket.id


    forwarded_values {
      query_string = false


      cookies {
        forward = "none"
      }
    }


    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }


  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["IN"]
    }
  }


  tags = {
    Name        = "Terra-CF-Distribution"
    Environment = "Production"
  }


  viewer_certificate {
    cloudfront_default_certificate = true
  }


  depends_on = [
    aws_s3_bucket.terra-bucket
  ]
}

resource "null_resource"  "nullres" {
    connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("/home/abhay/Desktop/aws/terraform_ec2_key")
    host     = aws_instance.web.public_ip
}
            provisioner "remote-exec" {
    inline = [
        "sudo yum -y install nfs-utils",
        "sudo mount -t nfs -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${aws_efs_file_system.newefs.id}:/   /var/www/html",
        "sudo su -c \"echo '${aws_efs_file_system.newefs.id}:/ /var/www/html nfs4 defaults,vers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport 0 0' >> /etc/fstab\"",
        "sudo git clone https://github.com/Abhay3008/facebook-data.git /var/www/html/",
        "sudo bash -c 'echo export url=${aws_s3_bucket.terra-bucket.bucket_domain_name} >> /etc/apache2/envvars'"
    ]
  }
}



