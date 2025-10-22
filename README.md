# 🚀 DevOps Automated Deployment

This project is part of the **HNG DevOps Internship — Stage 1 Task**.

It automates the process of deploying a Dockerized application on a remote Linux server using a Bash script.

---

## 🧰 Features
- Automatic server setup (Docker, Nginx)
- Git repository cloning and updates
- Docker image build and container run
- Nginx reverse proxy configuration
- Logging and validation

---

## ⚙️ How to Run

1. **Clone this repo**
   git clone https://github.com/Eng-babs/DevOps-deploy.git
   cd DevOps-deploy

2. **Make the deploy script executable**
   chmod +x deploy.sh

3. **Run the script**
   ./deploy.sh

4. Follow the prompts to enter:
   - GitHub repo URL
   - Branch name
   - Remote server username
   - IP address
   - SSH key path
   - Application port

---

## 📦 Application
This repo contains a simple Node.js app located in the app/ folder, which runs inside Docker.

---

## 🧹 Optional Cleanup
Run:
```bash
./deploy.sh --cleanup

## 👨‍💻 Author
**Eng-babs**  
DevOps Intern — HNG 2025

## 🌍 Live App
http://54.234.217.254
