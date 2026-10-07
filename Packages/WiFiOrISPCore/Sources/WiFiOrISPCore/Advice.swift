import Foundation

/// What someone pays their provider for.
public struct Plan: Codable, Equatable, Sendable {
    public var downMbps: Double
    public var upMbps: Double

    public init(downMbps: Double, upMbps: Double) {
        self.downMbps = downMbps
        self.upMbps = upMbps
    }
}

/// How a household uses its connection, to estimate the speeds it needs.
public struct HomeProfile: Codable, Equatable, Sendable {
    public var people: Int
    public var videoCalls: Bool
    public var gaming: Bool
    public var streams4K: Int
    public var bigUploads: Bool

    public init(
        people: Int = 2, videoCalls: Bool = true, gaming: Bool = false, streams4K: Int = 1, bigUploads: Bool = false
    ) {
        self.people = people
        self.videoCalls = videoCalls
        self.gaming = gaming
        self.streams4K = streams4K
        self.bigUploads = bigUploads
    }

    /// Rough needs with headroom: 10 Mbps a person, 25 per 4K stream, extra for gaming and calls.
    public var targetDownMbps: Double {
        max(25, Double(people) * 10 + Double(streams4K) * 25 + (gaming ? 15 : 0) + (videoCalls ? 5 : 0))
    }

    /// Video calls need about 3 Mbps up each; backups and video uploads need much more.
    public var targetUpMbps: Double {
        max(5, (videoCalls ? Double(people) * 3 : 2) + (bigUploads ? 20 : 0))
    }
}

/// Everything the advice is based on.
public struct AdviceContext: Sendable {
    public var verdict: Verdict
    public var latest: Sample?
    public var macSupports6GHz: Bool
    public var maker: RouterMaker?
    public var provider: Provider?
    public var plan: Plan?
    public var profile: HomeProfile?
    public var speedTests: [SpeedTestResult]
    public var lag: ResponsivenessResult?

    public init(
        verdict: Verdict, latest: Sample?, macSupports6GHz: Bool = false, maker: RouterMaker? = nil,
        provider: Provider? = nil, plan: Plan? = nil, profile: HomeProfile? = nil,
        speedTests: [SpeedTestResult] = [], lag: ResponsivenessResult? = nil
    ) {
        self.verdict = verdict
        self.latest = latest
        self.macSupports6GHz = macSupports6GHz
        self.maker = maker
        self.provider = provider
        self.plan = plan
        self.profile = profile
        self.speedTests = speedTests
        self.lag = lag
    }

    var providerName: String { provider?.name ?? "your provider" }
    var medianDownload: Double? { Statistics.median(speedTests.map(\.downloadMbps)) }
}

/// One thing to try next.
public struct NextStep: Equatable, Sendable {
    public enum Action: Equatable, Sendable {
        /// A page on wifiorisp.com, as a path like "/how-to-restart-router".
        case page(String)
        case runSpeedTest
        case runLagTest
        case exportReport
    }

    public var title: String
    public var action: Action?

    public init(_ title: String, _ action: Action? = nil) {
        self.title = title
        self.action = action
    }
}

/// A limit no setting will fix: the equipment or the plan itself.
public struct Ceiling: Equatable, Sendable {
    public enum Kind: String, Sendable {
        case wifiGeneration, wifiLink, smartQueue, plan, underdelivering
    }

    public var kind: Kind
    public var headline: String
    public var detail: String
    /// Where to look for a replacement, as a path on wifiorisp.com.
    public var recommendation: String
}

public enum Advice {
    // MARK: - Next steps

    public static func steps(_ context: AdviceContext) -> [NextStep] {
        switch context.verdict.kind {
        case .weakSignal, .goodWeakSignal: weakSignalSteps(context)
        case .localNetwork, .routerUnreachable, .offline: routerSteps(context)
        case .isp, .ispDown: ispSteps(context)
        case .notConnected: [NextStep("Turn on Wi-Fi, or join a network")]
        case .good, .measuring: goodSteps(context)
        }
    }

    private static func weakSignalSteps(_ context: AdviceContext) -> [NextStep] {
        var steps = [NextStep("Move closer to the router, or into the same room")]
        if context.latest?.wifi?.band == .ghz2 {
            steps.append(NextStep(
                "Join your router's 5 GHz network if it has one", .page("/how-to-change-wifi-channel")
            ))
        }
        steps.append(NextStep("Raise the router up and out of cabinets", .page("/wifi-signal-strength")))
        steps.append(NextStep("Still weak here? Add a mesh point", .page("/routers#mesh")))
        return steps
    }

    private static func routerSteps(_ context: AdviceContext) -> [NextStep] {
        let guide = context.maker?.guideSlug.map { "/router-login/\($0)" }
        let name = context.maker.map { "your \($0.name) router" } ?? "your router"
        var steps = [NextStep("Restart \(name)", .page(guide ?? "/how-to-restart-router"))]
        if context.verdict.kind == .localNetwork {
            steps.append(NextStep("Switch to a quieter Wi-Fi channel", .page(guide ?? "/how-to-change-wifi-channel")))
            steps.append(NextStep("Check for a router firmware update", .page(guide ?? "/router-login")))
        } else {
            steps.append(NextStep("Check that the router's lights look normal and its cables are in"))
        }
        return steps
    }

    private static func ispSteps(_ context: AdviceContext) -> [NextStep] {
        let page = context.provider?.guideSlug.map { "/\($0)" } ?? "/slow-internet"
        var steps = [
            NextStep("Check \(context.providerName)'s outage page", .page(page)),
            NextStep("Restart the modem (unplug it for a minute)", .page("/how-to-restart-router"))
        ]
        if context.verdict.kind == .isp {
            steps.append(NextStep("Run a speed test to see what you're getting", .runSpeedTest))
        }
        steps.append(NextStep("Still happening? Send \(context.providerName) your report", .exportReport))
        return steps
    }

    private static func goodSteps(_ context: AdviceContext) -> [NextStep] {
        context.lag == nil ? [NextStep("Check for lag under load (takes 15 seconds)", .runLagTest)] : []
    }

    // MARK: - Ceilings

    public static func ceilings(_ context: AdviceContext) -> [Ceiling] {
        [generationCeiling(context), linkCeiling(context), queueCeiling(context), planCeiling(context),
         underdeliveringCeiling(context)].compactMap { $0 }
    }

    /// The Mac can do Wi-Fi 6E or newer, but the connection is Wi-Fi 5 or older: the router is older than the Mac.
    static func generationCeiling(_ context: AdviceContext) -> Ceiling? {
        guard context.latest?.link == .wifi, let generation = context.latest?.wifi?.generation,
              generation <= .wifi5, context.macSupports6GHz
        else { return nil }
        return Ceiling(
            kind: .wifiGeneration,
            headline: "Your router is holding your Mac back",
            detail: "Your Mac supports Wi-Fi 6E, but it's connected with \(generation.label), the newest your router "
                + "offers. A Wi-Fi 6E or 7 router would be noticeably faster.",
            recommendation: "/routers#wifi-7"
        )
    }

    /// Speed tests top out near what the Wi-Fi link can carry, while the plan is faster.
    static func linkCeiling(_ context: AdviceContext) -> Ceiling? {
        guard let rate = context.latest?.wifi?.txRate, rate > 0, let download = context.medianDownload,
              let plan = context.plan, download >= rate * 0.55, plan.downMbps >= download * 1.3
        else { return nil }
        return Ceiling(
            kind: .wifiLink,
            headline: "Your Wi-Fi is slower than your plan",
            detail: "Speed tests reach about \(Int(download)) Mbps, close to what your Wi-Fi link carries "
                + "(\(Int(rate)) Mbps), while you pay for \(Int(plan.downMbps)). Moving closer helps; "
                + "a newer router or mesh fixes it.",
            recommendation: "/routers"
        )
    }

    /// Lag under load past the router, and the router has no smart queueing to fix it.
    static func queueCeiling(_ context: AdviceContext) -> Ceiling? {
        guard let lag = context.lag, lag.grade != .high, lag.queueLocation == .pastRouter,
              context.maker?.smartQueueSetting == nil
        else { return nil }
        let router = context.maker.map { $0.isConsumerRouter ? "Your \($0.name) router" : "Your provider's gateway" }
            ?? "Your router"
        return Ceiling(
            kind: .smartQueue,
            headline: "Your router can't fix lag under load",
            detail: "\(router) has no smart queueing, the setting that stops uploads and downloads from making "
                + "calls and games lag. A router with it, placed after your provider's equipment, fixes this.",
            recommendation: "/routers#calls-and-gaming"
        )
    }

    /// The plan itself is smaller than the household needs.
    static func planCeiling(_ context: AdviceContext) -> Ceiling? {
        guard let plan = context.plan, let profile = context.profile else { return nil }
        let shortUp = plan.upMbps < profile.targetUpMbps
        let shortDown = plan.downMbps < profile.targetDownMbps
        guard shortUp || shortDown else { return nil }
        let what = shortUp && shortDown ? "download and upload" : (shortUp ? "upload" : "download")
        return Ceiling(
            kind: .plan,
            headline: "Your plan is too small for your home",
            detail: "For how your household uses the internet, you need about \(Int(profile.targetDownMbps)) Mbps "
                + "down and \(Int(profile.targetUpMbps)) up. Your plan's \(what) falls short, "
                + "so no router will fix it.",
            recommendation: "/providers"
        )
    }

    /// Speed tests come in well under what the plan promises.
    static func underdeliveringCeiling(_ context: AdviceContext) -> Ceiling? {
        guard let plan = context.plan, context.speedTests.count >= 2, let download = context.medianDownload,
              download < plan.downMbps * 0.6, context.verdict.side != .yours
        else { return nil }
        let share = Int((download / plan.downMbps * 100).rounded())
        return Ceiling(
            kind: .underdelivering,
            headline: "You're getting about \(share)% of your plan",
            detail: "Your speed tests average \(Int(download)) Mbps against the \(Int(plan.downMbps)) you pay for. "
                + "That's worth raising with \(context.providerName), and the report shows it. If they can't fix it, "
                + "compare what else is available.",
            recommendation: "/providers"
        )
    }
}
