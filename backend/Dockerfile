# Use Node.js LTS image
FROM node:20-alpine

# Create application directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci

# Copy application source code
COPY . .

# Expose application port
EXPOSE 5003

# Start the application
CMD ["npm", "start"]
