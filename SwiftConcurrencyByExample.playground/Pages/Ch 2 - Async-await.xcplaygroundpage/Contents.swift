import Foundation
import _Concurrency

/**
 Async/await Playground support:
 - https://forums.swift.org/t/async-await-in-playgrounds/54145/11

 Running SwiftUI views in Playgrounds:
- https://www.swiftbysundell.com/tips/rendering-a-swiftui-view-in-a-playground/
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

//: ## How to call async throwing functions
//:
//: Function signatures are marked as `async throws` while call sites are marked as `try await`. This
func fetchFavorites() async throws -> [Int] {
    let url = URL(string: "https://hws.dev/user-favorites.json")!
    let (data, _) = try await URLSession.shared.data(from: url)
    return try JSONDecoder().decode([Int].self, from: data)
}

Task {
    if let favorites = try? await fetchFavorites() {
        print("Fetched \(favorites.count) favorites")
    } else {
        print("Failed to fetch favorites")
    }
}

//: ## What calls the first async function?
//:
//: Since async funcs can only be called from other async funcs, we're left in a bit of chicken or the egg problem.
//:
//: There are three main approaches, we'll be commonly reaching for:
//: 1. Using the `@main` attribute, we can declare our `main()` method to be async. Our program will immediately launch into an async func, so we can freely call other async funcs.
//func processWeather2() async {
//    // Do some async work here
//}

//@main
//struct MainApp {
//    static func main() async {
//        await processWeather2()
//    }
//}
//: 2. Apps built with SwiftUI have various places that can trigger async funcs such as `refreshable()` and `task()` modifiers
//:
//: As an example, we can write a simple "View Source" app that fetches the content of a website when our view appears
import SwiftUI
import PlaygroundSupport

struct ContentView1: View {
    @State private var sourceCode = ""

    var body: some View {
        ScrollView {
            Text(sourceCode)
        }
        .task {
            await fetchSource()
        }
    }

    func fetchSource() async {
        do {
            let url = URL(string: "https://apple.com")!
            let (data, _) = try await URLSession.shared.data(from: url)
            sourceCode = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            print("Failed to fetch apple.com")
        }
    }
}

//let view1 = ContentView1()
//PlaygroundPage.current.setLiveView(view1)
//:
//: 3. Swift provides the `Task` API which lets us call async funcs from sync funcs. This is possible only when we don't need to wait for the result of the `await` since our sync function still can't suspend itself. The task will start running immediately, and it'll always run to completion even if we don't store our task somewhere.
//:
//: The following is an example where we'll use a synchronous button press to start an async network call. We can achieve this because our sync button press is not waiting for the result of our async network call, and our `fetchSource()` call will be handling updating our UI with the result as well. We've decoupled the async and sync functions deliberately since the sync function can't await any results from the async func directly as it doesn't know how to suspend itself.
struct ContentView2: View {
    @State private var site = "https://"
    @State private var sourceCode = ""

    var body: some View {
        VStack {
            HStack {
                TextField("Website address", text: $site)
                    .textFieldStyle(.roundedBorder)
                Button("Go") {
                    Task {
                        await fetchSource()
                    }
                }
            }
            .padding()

            ScrollView {
                Text(sourceCode)
            }.frame(minWidth: 300, minHeight: 600)
        }
    }

    func fetchSource() async {
        do {
            let url = URL(string: site)!
            let (data, _) = try await URLSession.shared.data(from: url)
            sourceCode = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            sourceCode = "Failed to fetch \(site)"
        }
    }
}

let view2 = ContentView2()
PlaygroundPage.current.setLiveView(view2)

//: ## How to create and use async properties
//:
//: Computed properties can also be async. Same as async funcs, they need to be accessed with `await`, and `throws` if an error can be thrown while computing the property. Note that this is only possible with read-only computed properties and attempting to provide a setter will result in a compile error.
//:
//: As a demonstration, we can create a `RemoteFile` struct which stores a URL whose content is dynamically fetched each time the property is requested. Because `URLSession.shared` automatically caches our data, we'll create a custom URL session which will always ignore both local and remote caches to ensure the latest remote file is always fetched.
/// Custom URLSession which never caches
extension URLSession {
    static let noCacheSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        return URLSession(configuration: config)
    }()
}

/// Fetch and decode a remote file via its URL whenever its `content` property is read
struct RemoteFile<T: Decodable> {
    let url: URL
    let type: T.Type

    var contents: T {
        get async throws {
            let (data, _) = try await URLSession.noCacheSession.data(from: url)
            return try JSONDecoder().decode(type.self, from: data)
        }
    }
}
//: As an example where this could be used is a view that fetches messages. We never want stale data, so we're going to point our `RemoteFile` struct at a particular URL and tell it to expect an array of messages in response. All of the fetching, decoding, and cache bypass behavior is still neatly abstracted into our `RemoteFile` struct, so our view code remains nice and light!
struct Message: Decodable, Identifiable {
    let id: Int
    let user: String
    let text: String
}

struct MessageView: View {
    let source = RemoteFile(url: URL(string: "https://hws.dev/inbox.json")!, type: [Message].self)
    @State private var messages = [Message]()

    var body: some View {
        NavigationView {
            List(messages) { message in
                VStack(alignment: .leading) {
                    Text(message.user)
                        .font(.headline)
                    Text(message.text)
                }
            }
            .navigationTitle("Inbox")
            .toolbar {
                Button(action: refresh) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
            .onAppear(perform: refresh)
        }
    }

    func refresh() {
        Task {
            do {
                messages = try await source.contents
            } catch {
                print("Message update failed")
            }
        }
    }
}
//: To see the above view code in use, you'll need to use Xcode Live Previews. 😔
//:
//: But we got you! It's nestled in the Swift Playground app in this workspace under `Ch2/MessagesView`! 🥳

//: ## How to call an async func using async let
//:
//: When you want to run several async ops concurrently and do not need to wait for their results to come back, you can use `async let`. This allows each of the async funcs to run immediately which is much more efficient than running each sequentially when the operations don't rely on the result of each other or modify the same data.
//:
//: For example, if we needed to make two unrelated network requests, using `async let` would be perfect to fire off both network requests concurrently.
//:
//: Lets begin by defining a couple of structs to store data -- one to store the user's account data and one to store all the messages in their inbox.
struct User: Decodable {
    let id: UUID
    let name: String
    let age: Int
}

struct Message_2: Decodable, Identifiable {
    let id: Int
    let from: String
    let message: String
}
//: Because these can be fetched independently of each other, we can use `async let` instead of `await`
func loadData() async {
    async let (userData, _) = URLSession.shared.data(from: URL(string: "https://hws.dev/user-24601.json")!)
    async let (messageData, _) = URLSession.shared.data(from: URL(string: "https://hws.dev/user-messages.json")!)

    do {
        let decoder = JSONDecoder()
        let user = try await decoder.decode(User.self, from: userData)
        let messages = try await decoder.decode([Message_2].self, from: messageData)
        print("User \(user.name) has \(messages.count) message(s)")
    } catch {
        print("Sorry, there was a network problem")
    }
}

Task {
    await loadData()
}
//: You'll notice that when we write `async let`, we don't need to include `try` since that's handled when we read our values. This combination with `async let` allows us to start both of our network requests concurrently, but we must `try await` our results sequentially. If we want to read our network responses as they come back, we would need to use the `Task` API to do so.
//:
//: It's important to note that `await` is useful when we make dependent async requests that must run sequentially. Where the work is unrelated, we can run our requests concurrently using `async let` and we can later `await` the results sequentially

//: ## Why can't we call async functions using async var?
//:
//: The restriction of not being able to use mutatable, capturable variables makes sense. Lets consider the following pseudocode example
//func fetchUsername() async -> String {
//    "jboo"
//}
//
//async var username = fetchUsername()
//username = "achacha"
//print(username)
//: We now have a race with our async function completing and the `username` being set. To avoid the ambiguity this causes, it's not allowed by Swift. Instead, we must use `async let` to make username a constant.

//: ## How to use continuations to convert completion handlers into async functions
//:
//: When older Swift code using completion handlers needs to be used from an async func, we have `continuations` to create this bridge.
//:
//: Lets first consider a typical network request to fetch data from a server, decode it, and return the decoded data to its caller using competion handlers.
struct Message_3: Decodable, Identifiable {
    let id: Int
    let from: String
    let message: String
}

func fetchMessages(completion: @escaping ([Message_3]) -> Void) {
    let url = URL(string: "https://hws.dev/user-messages.json")!

    URLSession.shared.dataTask(with: url) { data, response, error in
        if let data = data {
            if let messages = try? JSONDecoder().decode([Message_3].self, from: data) {
                completion(messages)
                return
            }
        }
        completion([])
    }.resume()
}
//: In order to use this call within our own async funcs, we can use `Continuations` which are special objects we can pass into the completion handlers as captured values. Once the completion handler fires, we can:
//: 1. Return the finished value
//: 2. Throw an error
//: 3. Send back a `Result` to be handled elewhere
//: We can wrap our original `fetchMessages(completion:)` call with an async version that returns `[Message]`
func fetchMessages() async -> [Message_3] {
    await withCheckedContinuation { continuation in
        fetchMessages { messages in
            continuation.resume(returning: messages)
        }
    }
}
Task {
    let messages = await fetchMessages()
    print("Downloaded \(messages.count) messages.")
}
//: The key to checked continuations is that they are "checked" by Swift that we're using the continuation correctly.
//:
//: Continuations must be resumed **exactly once**. The program will crash if we call it more than once which is prefereable to the undefined behavior if we call it more than once.
//:
//: Equally, if we fail to resume our continutaion, we'll see a large warning in the debug log similar to "SWIFT TASK CONTINUATION MISUSE: fetchMessages() leaked its continuation!”. This occurs because if we leave our task suspended, we're causing the program to hold any resources indefinitely.

//: ## How to create continuations that can throw errors
//:
//: 





//: [Previous](@previous)      [Next](@next)
