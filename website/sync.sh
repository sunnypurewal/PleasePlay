aws s3 sync . s3://sonnio-website --exclude '.git/*' --exclude '*.sh' --delete --exclude '.DS_Store'
