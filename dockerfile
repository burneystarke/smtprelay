FROM golang:1.25.4-trixie@sha256:728cbef6ce5da50a5da2455cf8a13ddc4f71eb5a3245d9a5a3cce260f8ca9898 AS build
ARG COMMITHASH
WORKDIR /src
ENV CGO_ENABLED=0
ENV CC=gcc
RUN wget -qO- https://github.com/grafana/smtprelay/archive/${COMMITHASH}.tar.gz | tar xzf - --strip-components=1
RUN go get
RUN go build -ldflags="-extldflags -static -s -w" -o smtprelay
RUN chmod 555 smtprelay
FROM gcr.io/distroless/static-debian12
COPY --from=build /src/smtprelay /smtprelay
USER nonroot:nonroot
ENTRYPOINT ["/smtprelay"]
CMD ["--help"]
