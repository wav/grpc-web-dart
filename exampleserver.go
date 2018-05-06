package main

import (
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/grpclog"
	"google.golang.org/grpc/metadata"

	"strings"

	library "github.com/improbable-eng/grpc-web/example/go/_proto/examplecom/library"
	"github.com/improbable-eng/grpc-web/go/grpcweb"
	"golang.org/x/net/context"
)

var (
	enableTls       = flag.Bool("enable_tls", false, "Use TLS - required for HTTP2.")
	tlsCertFilePath = flag.String("tls_cert_file", "../misc/localhost.crt", "Path to the CRT/PEM file.")
	tlsKeyFilePath  = flag.String("tls_key_file", "../misc/localhost.key", "Path to the private key file.")
)

func main() {
	flag.Parse()

	port := 9090
	if *enableTls {
		port = 9091
	}

	var unaryInterceptor grpc.UnaryServerInterceptor = func(ctx context.Context, req interface{}, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (resp interface{}, err error) {
		println("unary", info.FullMethod)
		ctx, _ = context.WithDeadline(ctx, time.Now().Add(1*time.Second))
		return handler(ctx, req)
	}

	var streamInterceptor grpc.StreamServerInterceptor = func(srv interface{}, ss grpc.ServerStream, info *grpc.StreamServerInfo, handler grpc.StreamHandler) error {
		println("stream", info.FullMethod)
		return handler(srv, ss)
	}

	grpcServer := grpc.NewServer(
		grpc.StreamInterceptor(streamInterceptor),
		grpc.UnaryInterceptor(unaryInterceptor),
	)
	library.RegisterBookServiceServer(grpcServer, &bookService{})
	grpclog.SetLogger(log.New(os.Stdout, "exampleserver: ", log.LstdFlags))

	wrappedServer := grpcweb.WrapServer(grpcServer)
	handler := func(resp http.ResponseWriter, req *http.Request) {
		println(req.RequestURI)
		wrappedServer.ServeHTTP(resp, req)
	}

	httpServer := http.Server{
		Addr:         fmt.Sprintf("127.0.0.1:%d", port),
		Handler:      http.HandlerFunc(handler),
		WriteTimeout: 1 * time.Second,
		IdleTimeout:  1 * time.Second,
		ReadTimeout:  1 * time.Second,
	}

	grpclog.Printf("Starting server. http port: %d, with TLS: %v", port, *enableTls)

	if *enableTls {
		if err := httpServer.ListenAndServeTLS(*tlsCertFilePath, *tlsKeyFilePath); err != nil {
			grpclog.Fatalf("failed starting http2 server: %v", err)
		}
	} else {
		if err := httpServer.ListenAndServe(); err != nil {
			grpclog.Fatalf("failed starting http server: %v", err)
		}
	}
}

type bookService struct{}

var books = []*library.Book{
	{
		Isbn:   60929871,
		Title:  "Brave New World",
		Author: "Aldous Huxley",
	},
	{
		Isbn:   140009728,
		Title:  "Nineteen Eighty-Four",
		Author: "George Orwell",
	},
	{
		Isbn:   9780140301694,
		Title:  "Alice's Adventures in Wonderland",
		Author: "Lewis Carroll",
	},
	{
		Isbn:   140008381,
		Title:  "Animal Farm",
		Author: "George Orwell",
	},
}

func (s *bookService) GetBook(ctx context.Context, bookQuery *library.GetBookRequest) (*library.Book, error) {
	println("GetBook:", bookQuery.Isbn)

	grpc.SendHeader(ctx, metadata.Pairs("Pre-Response-Metadata", "Is-sent-as-headers-unary"))
	grpc.SetTrailer(ctx, metadata.Pairs("Post-Response-Metadata", "Is-sent-as-trailers-unary"))

	for _, book := range books {
		if book.Isbn == bookQuery.Isbn {
			return book, nil
		}
	}

	return nil, grpc.Errorf(codes.NotFound, "Book could not be found")
}

func (s *bookService) QueryBooks(bookQuery *library.QueryBooksRequest, stream library.BookService_QueryBooksServer) error {
	println("GetBooks:", bookQuery.AuthorPrefix)
	stream.SendHeader(metadata.Pairs("Pre-Response-Metadata", "Is-sent-as-headers-stream"))
	for _, book := range books {
		if strings.HasPrefix(book.Author, bookQuery.AuthorPrefix) {
			stream.Send(book)
		}
	}
	stream.SetTrailer(metadata.Pairs("Post-Response-Metadata", "Is-sent-as-trailers-stream"))
	return nil
}
