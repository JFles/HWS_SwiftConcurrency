import Foundation
import _Concurrency

/**
 Async/await Playground support:
 - https://forums.swift.org/t/async-await-in-playgrounds/54145/11
 */

//: # Ch 2 - Async/await
//:
//: ## What is an asynchronous function?
//:
//: To make Swift functions asynchronous, we add the `async` keyword to its method signature. Inside of our async funcs, we call other async funcs by using the `await` keyword.
//:
//: For example, here's a simple example first as a synchronous func
func randomD6() -> Int {
    print("Sync")
    return Int.random(in: 1...6)
}

let result1 = randomD6()
print(result1)
//: And here's our async version of the same function
func randomD6() async -> Int {
    print("Async")
    return Int.random(in: 1...6)
}
// Have to wrap this in a task to notify the playground that we're no longer in a synchronous context?
Task {
    let result2 = await randomD6()
    print(result2)
}
//: Notice that in our above async function we aren't `awaiting` anything. By marking our func as `async`, we're declaring that our func *may* do async work, not that it *must*. The same is true in the case of functions which are marked as `throws`.
//:
//: By specifing `await` when we call our async func, we denote that the function we're calling is asynchronous and marking it as a potential suspension point where we are waiting for the result to come back before resuming.
//:
//: Lets consider an example which is actually awaiting a result from a server call
func fetchNews() async -> Data? {
    do {
        let url = URL(string: "https://hws.dev/news-1.json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    } catch {
        print("Failed to fetch data")
        return nil
    }
}
Task {
    if let data = await fetchNews() {
        print("Downloaded \(data.count) bytes")
    } else {
        print("Download failed")
    }
}
//: Instead of writing a completion handler for our URLSession request to complete when the network response is returned, we mark our code with `await` to mark our suspension point. One benefit this brings us is that our code has been flattened which increases readability with a more linear flow. An additional benefit is that we no longer have to worry about forgetting to call `completion` on multiple paths such as `guard-else` preconditions where it's very easy to do so.
//:
//:
//: The differences between sync and async funcs are as follows:
//: 1. When our async func is suspended, all async funcs which called it are also suspended. This is also why sync func cannot directly call async funcs -- the sync funcs do not know how to suspend themselves.
//: 2. An async func can be suspended as many times as needed -- but only when there is an explicit `await`
//: 3. An async func won't block the thread it's running on and will instead give up the thread for other work to be run
//: 4. When the asynbc func resumes, it might not be running on the same thread, and the state of the program may have changed, so we shouldn't make assumptions of program state
//: 5. `await` marks a *potential* suspension point -- but it isn't guranteed that the work *will* be suspended if not needed.

//: ## How to create and call an async function
//:
//: The following is an example where we want to download a bunch of temp readings from a weather station, calc the avg temp, then upload the results. We can make each of these funcs async as network calls should always run aynchronously and computations can take a long time to complete.
//:
//: To use our func, we would need a fourth func which calls each func in order and prints responses. Because any of the async funcs could potentially suspend, our stitching func also needs to be async as it may need to be suspended as well.
func fetchWeatherHistory() async -> [Double] {
    (1...100_000).map { _ in Double.random(in: -10...30) }
}

func calculateAverageTemperature(for records: [Double]) async -> Double {
    let total = records.reduce(0, +)
    let average = total / Double(records.count)
    return average
}

func upload(result: Double) async -> String {
    "OK"
}

func processWeather() async {
    let records = await fetchWeatherHistory()
    let average = await calculateAverageTemperature(for: records)
    let response = await upload(result: average)
    print("Server response: \(response)")
}

Task {
    await processWeather()
}
//: When reading async functions like `processWeather()`, it's helpful to look for each `await` call because they are all the places where an unknown amount of work might take place before the next line of code executes.
//:
//: If we were relying on props from a class here, they could have changed between each of the `await` lines.
//:
//: We could protect against this using a system known as `Actors` which we'll get into at a later point.




//: [Previous](@previous)      [Next](@next)
