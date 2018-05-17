FROM alpine as zstd-builder

RUN apk --no-cache add make gcc libc-dev git

RUN git clone https://github.com/facebook/zstd src

RUN mkdir /pkg && cd /src && make && make DESTDIR=/pkg install

# Second minimal image to only keep the built binary
FROM electrotumbao/golang-protoc as go-builder

RUN apk update && apk add bash git unzip

WORKDIR /go/src/github.com/m-lab
RUN git clone https://github.com/m-lab/tcp-info
WORKDIR tcp-info
# allows override with --build-args COMMIT=branch-or-commit, defaults to master
ARG COMMIT=master
RUN echo $COMMIT
RUN git checkout $COMMIT

# List all of the go imports, excluding any in this repo, and run go get to import them.
RUN go get -u -v $(go list -f '{{join .Imports "\n"}}{{"\n"}}{{join .TestImports "\n"}}' ./... | sort | uniq | grep -v m-lab/tcp-info)
RUN go get github.com/golang/protobuf/protoc-gen-go/ github.com/golang/protobuf/proto

WORKDIR nl-proto
RUN protoc --go_out=. *.proto
WORKDIR ..

# Install all go executables.  Creates all build targets in /go/bin directory.
RUN go install -v ./...

FROM alpine

RUN apk --no-cache add bash


# Copy the built files (from /pkg/usr/local/bin)
COPY --from=zstd-builder /pkg /

# Copy the license as well
RUN mkdir -p /usr/local/share/licenses/zstd
COPY --from=zstd-builder /src/LICENSE /usr/local/share/licences/zstd/

COPY --from=go-builder /go/bin /usr/local/bin

EXPOSE 9090 8080

WORKDIR /home
CMD tcp-info