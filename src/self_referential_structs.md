# Self-referential structs
Here is another problem that may often stand in the way. 

Imagine a Kafka library (like [rdkafka](https://github.com/fede1024/rust-rdkafka)), that has an interface similar to:
```Rust
struct KafkaConsumer;

struct MessageStream<'a> {
    consumer: &'a KafkaConsumer
}

impl KafkaConsumer {
    fn new() -> KafkaConsumer {
        KafkaConsumer {}
    }

    fn stream(&self, topic: &str) -> MessageStream {
        MessageStream { consumer: self }
    }
}
```
Now let's say you need to start multiple stream dynamically - you don't know how many beforehand. These streams will read different topics therefore they need their own consumers.
```Rust
fn create_stream(topic: &str) -> MessageStream {
    let consumer = KafkaConsumer::new();
    consumer.stream(topic)
}
```
This obviously doesn't work:
```
error[E0597]: `consumer` does not live long enough
  --> src/main.rs:29:5
   |
29 |     consumer.stream(topic)
   |     ^^^^^^^^ borrowed value does not live long enough
30 | }
   | - borrowed value only lives until here
```
But what if we returned consumer together with the stream?
```Rust
struct KafkaStream {
    consumer: KafkaConsumer,
    stream: MessageStream<'static>
}

fn create_stream(topic: &str) -> KafkaStream {
    let consumer = KafkaConsumer::new();
    let stream = consumer.stream(topic);
    KafkaStream {
        consumer,
        stream
    }
}
```
Still no luck!
```
error[E0597]: `consumer` does not live long enough
  --> src/main.rs:39:18
   |
39 |     let stream = consumer.stream(topic);
   |                  ^^^^^^^^ borrowed value does not live long enough
...
44 | }
   | - borrowed value only lives until here
   |
   = note: borrowed value must be valid for the static lifetime...
```
Maybe Rust compiler is just dumb?
```Rust
struct KafkaStream {
    consumer: KafkaConsumer,
    stream: MessageStream<'static>
}

fn create_stream(topic: &str) -> KafkaStream {
    let consumer = KafkaConsumer::new();
    let consumer_ref: &'static KafkaConsumer = unsafe { mem::transmute(&consumer) };
    let stream = consumer_ref.stream(topic);
    KafkaStream {
        consumer,
        stream
    }
}
```
This compiles! However this is really NOT SAFE. Turns out it can actually CRASH!
The reason is we did a dumb thing here: we forced Rust to think that consumer reference is valid forever, but the actual object can be moved when function returnes (it's address will change)!

So how do we make it actually safe? By placing the object on heap:
```Rust
struct KafkaStream {
    consumer: Box<KafkaConsumer>,
    stream: MessageStream<'static>
}

fn create_stream(topic: &str) -> KafkaStream {
    let consumer = KafkaConsumer::new();
    let consumer = Box::new(consumer);
    let consumer_ref: &'static KafkaConsumer = unsafe { mem::transmute(consumer.as_ref()) };
    let stream = consumer_ref.stream(topic);
    KafkaStream {
        consumer,
        stream
    }
}
```
That's almost perfect!
Except.. it's not. We forgot one importnant detail: drop order.

We need our consumer to be disposed after the stream.
Luckily Rust struct drop order has been [stabilized](https://github.com/rust-lang/rfcs/blob/master/text/1857-stabilize-drop-order.md) recently, so we can just change the order of fields in our struct.
This is the final solution:
```Rust
struct KafkaStream {
    stream: MessageStream<'static>,
    consumer: Box<KafkaConsumer>
}

fn create_stream(topic: &str) -> KafkaStream {
    let consumer = KafkaConsumer::new();
    let consumer = Box::new(consumer);
    let consumer_ref: &'static KafkaConsumer = unsafe { mem::transmute(consumer.as_ref()) };
    let stream = consumer_ref.stream(topic);
    KafkaStream {
        consumer,
        stream
    }
}
```

