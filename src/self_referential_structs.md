# Self-referential structs
Here is another problem that may often stand in the way. 

Imagine you need to start multiple asynchronous Kafka consumers (with [rdkafka](https://github.com/fede1024/rust-rdkafka)), but you don't know how many beforehand. You need to return a ```Stream``` from some function, but you can't, because streams you create are tied to the consumer.

## The solution
```Rust
struct KafkaConsumerStream<'a, T> {
    stream: Box<Stream<Item=T, Error=Error> + 'a>,
    consumer: Box<StreamConsumer>,
}

let consumer = ...;
let consumer = Box::new(consumer);
let consumer_ref: &'a StreamConsumer = unsafe { mem::transmute(consumer.as_ref()) };
let stream = ...;
let stream = Box::new(stream);
KafkaConsumerStream {
    consumer,
    stream,
}
```