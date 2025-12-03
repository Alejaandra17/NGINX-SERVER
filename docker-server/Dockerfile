# 1. Use the official Nginx image
FROM nginx:latest

# 2. Remove default Nginx static assets
RUN rm -rf /usr/share/nginx/html/*

# 3. Copy your local 'html' folder (Path fixed: it is inside 'config')
COPY ./config/html /usr/share/nginx/html

# 4. Copy your local configuration file (Path fixed: it is inside 'config/conf')
COPY ./config/conf/nginx.conf /etc/nginx/conf.d/default.conf

# 5. Expose the internal port
EXPOSE 80