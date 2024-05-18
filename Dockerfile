# Use an official Perl runtime as a parent image
FROM perl:5.30

# Set the working directory in the container to /app
WORKDIR /app

# Copy the current directory contents into the container at /app
COPY . /app

# Install make
RUN apt-get update && apt-get install -y make

# Run make install to install dependencies
RUN make install

# Set default values for HOST and PORT
ENV HOST=*
ENV PORT=80

# Make port 80 available to the world outside this container
EXPOSE 80

# Run the app when the container launches
CMD ["perl", "app.pl", "daemon", "-l", "http://$HOST:$PORT"]