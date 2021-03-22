#if canImport(Combine)
  import Combine
  import Foundation

  /// A scheduler for performing synchronous actions.
  ///
  /// You can only use this scheduler for immediate actions. If you attempt to schedule actions
  /// after a specific date, this scheduler ignores the date and performs them immediately.
  ///
  /// This scheduler is useful for writing tests against publishers that use asynchrony operators,
  /// such as `receive(on:)`, `subscribe(on:)` and others, because it forces the publisher to emit
  /// immediately rather than needing to wait for thread hops or delays using `XCTestExpectation`.
  ///
  /// This scheduler is different from `TestScheduler` in that you cannot explicitly control how
  /// time flows through your publisher, but rather you are instantly collapsing time into a single
  /// point.
  ///
  /// As a basic example, suppose you have a view model that loads some data after waiting for 10
  /// seconds from when a button is tapped:
  ///
  ///     class HomeViewModel: ObservableObject {
  ///       @Published var episodes: [Episode]?
  ///
  ///       let apiClient: ApiClient
  ///
  ///       init(apiClient: ApiClient) {
  ///         self.apiClient = apiClient
  ///       }
  ///
  ///       func reloadButtonTapped() {
  ///         Just(())
  ///           .delay(for: .seconds(10), scheduler: DispachQueue.main)
  ///           .flatMap { apiClient.fetchEpisodes() }
  ///           .assign(to: &self.episodes)
  ///       }
  ///     }
  ///
  /// In order to test this code you would literally need to wait 10 seconds for the publisher to
  /// emit:
  ///
  ///     func testViewModel() {
  ///       let viewModel = HomeViewModel(apiClient: .mock)
  ///
  ///       viewModel.reloadButtonTapped()
  ///
  ///       _ = XCTWaiter.wait(for: [XCTestExpectation()], timeout: 10)
  ///
  ///       XCTAssert(viewModel.episodes, [Episode(id: 42)])
  ///     }
  ///
  /// Alternatively, we can explicitly pass a scheduler into the view model initializer so that it
  /// can be controller from the outside:
  ///
  ///     class HomeViewModel: ObservableObject {
  ///       @Published var episodes: [Episode]?
  ///
  ///       let apiClient: ApiClient
  ///       let scheduler: AnySchedulerOf<DispatchQueue>
  ///
  ///       init(apiClient: ApiClient, scheduler: AnySchedulerOf<DispatchQueue>) {
  ///         self.apiClient = apiClient
  ///         self.scheduler = scheduler
  ///       }
  ///
  ///       func reloadButtonTapped() {
  ///         Just(())
  ///           .delay(for: .seconds(10), scheduler: self.scheduler)
  ///           .flatMap { self.apiClient.fetchEpisodes() }
  ///           .assign(to: &self.$episodes)
  ///       }
  ///     }
  ///
  /// And then in tests use an immediate scheduler:
  ///
  ///     func testViewModel() {
  ///       let viewModel = HomeViewModel(
  ///         apiClient: .mock,
  ///         scheduler: DispatchQueue.immediateScheduler.eraseToAnyScheduler()
  ///       )
  ///
  ///       viewModel.reloadButtonTapped()
  ///
  ///       // No more waiting...
  ///
  ///       XCTAssert(viewModel.episodes, [Episode(id: 42)])
  ///     }
  ///
  /// - Note: This scheduler can _not_ be used to test publishers with more complex timing logic,
  ///   like those that use `Debounce`, `Throttle`, or `Timer.Publisher`, and in fact
  ///   `ImmediateScheduler` will not schedule this work in a defined way. Use a `TestScheduler`
  ///   instead to capture your publisher's timing behavior.
  ///
  @available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
  public struct ImmediateScheduler<SchedulerTimeType, SchedulerOptions>: Scheduler
  where
    SchedulerTimeType: Strideable,
    SchedulerTimeType.Stride: SchedulerTimeIntervalConvertible
  {

    public let minimumTolerance: SchedulerTimeType.Stride = .zero
    public let now: SchedulerTimeType

    /// Creates an immediate test scheduler with the given date.
    ///
    /// - Parameter now: The current date of the test scheduler.
    public init(now: SchedulerTimeType) {
      self.now = now
    }

    public func schedule(options _: SchedulerOptions?, _ action: () -> Void) {
      action()
    }

    public func schedule(
      after _: SchedulerTimeType,
      tolerance _: SchedulerTimeType.Stride,
      options _: SchedulerOptions?,
      _ action: () -> Void
    ) {
      action()
    }

    public func schedule(
      after _: SchedulerTimeType,
      interval _: SchedulerTimeType.Stride,
      tolerance _: SchedulerTimeType.Stride,
      options _: SchedulerOptions?,
      _ action: () -> Void
    ) -> Cancellable {
      action()
      return AnyCancellable {}
    }
  }

  @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
  extension Scheduler
  where
    SchedulerTimeType == DispatchQueue.SchedulerTimeType,
    SchedulerOptions == DispatchQueue.SchedulerOptions
  {
    public static var immediateScheduler: ImmediateSchedulerOf<Self> {
      // NB: `DispatchTime(uptimeNanoseconds: 0) == .now())`. Use `1` for consistency.
      ImmediateScheduler(now: SchedulerTimeType(DispatchTime(uptimeNanoseconds: 1)))
    }
  }

  @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
  extension Scheduler
  where
    SchedulerTimeType == RunLoop.SchedulerTimeType,
    SchedulerOptions == RunLoop.SchedulerOptions
  {
    public static var immediateScheduler: ImmediateSchedulerOf<Self> {
      ImmediateScheduler(now: SchedulerTimeType(Date(timeIntervalSince1970: 0)))
    }
  }

  @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
  extension Scheduler
  where
    SchedulerTimeType == OperationQueue.SchedulerTimeType,
    SchedulerOptions == OperationQueue.SchedulerOptions
  {
    public static var immediateScheduler: ImmediateSchedulerOf<Self> {
      ImmediateScheduler(now: SchedulerTimeType(Date(timeIntervalSince1970: 0)))
    }
  }

  /// A convenience type to specify an `ImmediateScheduler` by the scheduler it wraps rather than by
  /// the time type and options type.
  @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
  public typealias ImmediateSchedulerOf<Scheduler> = ImmediateScheduler<
    Scheduler.SchedulerTimeType, Scheduler.SchedulerOptions
  > where Scheduler: Combine.Scheduler
#endif