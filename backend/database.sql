CREATE DATABASE IF NOT EXISTS blog_db;
USE blog_db;

CREATE TABLE IF NOT EXISTS posts (
  id INT AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  content TEXT NOT NULL,
  author VARCHAR(100) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO posts (title, content, author) VALUES
('Welcome to the Blog', 'This is the first post on our Simple Blog App running on EKS.', 'Admin'),
('DevOps Journey', 'Building CI/CD with GitHub Actions, Argo CD, Prometheus and Grafana.', 'DevOps Trainee');
