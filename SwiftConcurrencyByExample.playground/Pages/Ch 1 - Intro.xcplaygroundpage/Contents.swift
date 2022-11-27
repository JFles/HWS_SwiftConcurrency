import UIKit

//: # Ch 1: Introduction
//:
//: ## Concurrency vs Parallelism
//:
//: The following quote from famous computer scientist, Rob Pike, summarizes the difference between concurrency and parallelism:
//:
//: "Concurrency is about dealing with many things at once, parallelism is about doing many things at once. Concurrency is a way to structure things so you can maybe use parallelism to do a better job."
//:
//: Swapping threads is known as a `context switch`, and it has a performance cost. The system needs to stash all the data the thread was using and remember how far the thread had progressed in its work before the system can give another thread the chance to run.
//:
//: If this happens a lot, such as in the case of creating many more threads than CPU cores, then the cost of context switching grows very large known as `thread explosion`





//: [Next](@next)
