FROM public.ecr.aws/nginx/nginx:latest

COPY nginx.conf /etc/nginx/nginx.conf 
COPY image.png /usr/share/nginx/html
COPY index.html /usr/share/nginx/html

ENTRYPOINT ["nginx", "-g", "daemon off;"]
