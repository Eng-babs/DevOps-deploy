# Use an official Node.js runtime
FROM node:18-alpine

# Create app directory
WORKDIR /usr/src/app

# Copy files
COPY package*.json ./
COPY app.js .

# Expose port 3000
EXPOSE 3000

# Command to run app
CMD ["node", "app.js"]
