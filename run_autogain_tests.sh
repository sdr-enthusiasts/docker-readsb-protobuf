

# Build readsb_autogain_testing_base image
docker build -t readsb_autogain_testing_base .

# Build readsb_autogain_testing image
docker build -f Dockerfile.autogain_testing -t readsb_autogain_testing .

docker run --rm -it readsb_autogain_testing