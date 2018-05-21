# Interior mutability
There is a [whole page](https://doc.rust-lang.org/book/second-edition/ch15-05-interior-mutability.html) in the official Rust book about the subject.
But the hint is that in many cases, it may be very useful or even neccessary to design application components using interior mutability.
Like if we had to modify state in the closures in the previous example, we could get away with something like that:
```Rust

struct App {
    counter: Counter
}

struct Counter {
    state: Cell<i32>
}

impl Counter {
    fn new() -> Counter {
        Counter {
            state: Cell::new(0)
        }
    }

    fn inc_and_get(&self) -> i32 {
        let value = self.state.get();
        self.state.set(value + 1);
        value
    }
}

impl App {
    fn start<'a>(&'a mut self) -> impl Future<Item=i32, Error=()> + 'a {
        self.init();
        self.start_work()
    }

    fn init<'a>(&'a mut self) {
        self.counter = Counter::new();
    }

    fn start_work<'a>(&'a self) -> impl Future<Item=i32, Error=()> + 'a {
        futures::finished(0)
            .map(move |x| x + self.counter.inc_and_get())
            .map(move |x| x + self.counter.inc_and_get())
    }
}
```
This allow us to keep immutable references and easily move them into closures.
However once we have multiple threads - we should also take care of synchronization too.