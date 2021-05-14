import UIKit

typealias AccountId = UUID
typealias Balance = UInt

struct AccountPair : Hashable {
    var pair : (p: UUID, q: UUID)

    func hash(into hasher: inout Hasher) {
        hasher.combine(pair.p.hashValue + pair.q.hashValue)
    }

    static func == (lhs: AccountPair, rhs: AccountPair) -> Bool {
        return lhs.pair == rhs.pair
    }
}

protocol EventEmitable {}

struct Transfer: EventEmitable {
    let from: AccountId?
    let to: AccountId?
    let value: Balance
}

struct Approval: EventEmitable {
    let owner: AccountId
    let spender: AccountId
    let value: Balance
}

struct ENV {
    static let alice = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let bob = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    static let chris = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!

    static func emit_event(_ event: EventEmitable) {
        print(event)
    }
}

var caller: UUID = ENV.alice

struct ERC20 {
    /// The total supply.
    private let total_supply: Balance
    /// The balance of each user.
    private var balances: [AccountId: Balance]
    /// Approval spender on behalf of the message's sender.
    private var allowances: [AccountPair: Balance]

    init(initial_supply: Balance) {
        self.total_supply = initial_supply
        self.balances = [AccountId : Balance]()
        self.balances[caller] = initial_supply
        self.allowances = [AccountPair: Balance]()

        ENV.emit_event(
            Transfer(from: nil,
                     to: caller,
                     value: initial_supply))
    }

    public func totalSupply() -> Balance {
        return total_supply
    }

    public func balanceOf(owner: AccountId) -> Balance {
        return balanceOfOrZero(owner: owner)
    }

    public mutating func approve(spender: AccountId, value: Balance) -> Bool {
        let owner = caller
        allowances[AccountPair(pair: (p: owner, q: spender))] = value
        ENV.emit_event(
            Approval(owner: owner,
                     spender: spender,
                     value: value))
        return true
    }

    public mutating func transferFrom(from: AccountId, to: AccountId, value: Balance) -> Bool {
        let allowance = allowanceOfOrZero(owner: from, spender: caller)
        if allowance < value {
            return false
        }
        allowances[AccountPair(pair: (p: from, q: caller))] = value
        return transferFromTo(from: from, to: to, value: value)
    }

    public mutating func transfer(to: AccountId, value: Balance) -> Bool {
        return transferFromTo(from: caller, to: to, value: value)
    }

    private mutating func transferFromTo(from: AccountId, to: AccountId, value: Balance) -> Bool {
        let fromBalance = balanceOfOrZero(owner: from)
        if fromBalance < value {
            return false
        }

        balances[from] = fromBalance - value

        let toBalance = balanceOfOrZero(owner: to)
        balances[to] = toBalance + value

        ENV.emit_event(
            Transfer(from: from,
                     to: to,
                     value: value))
        return true
    }

    public func allowance(owner: AccountId, spender: AccountId) -> Balance {
        return self.allowanceOfOrZero(owner: owner, spender: spender)
    }

    private func balanceOfOrZero(owner: AccountId) -> Balance {
        return self.balances[owner] ?? 0
    }

    private func allowanceOfOrZero(owner: AccountId, spender: AccountId) -> Balance {
        return self.allowances[AccountPair(pair: (p: owner, q: spender))] ?? 0
    }
}

caller = ENV.alice
var tokenContract = ERC20(initial_supply: 100)
tokenContract.approve(spender: ENV.bob, value: 10)

caller = ENV.bob
tokenContract.transferFrom(from: ENV.alice, to: ENV.chris, value: 9)

tokenContract.balanceOf(owner: ENV.alice)
tokenContract.balanceOf(owner: ENV.bob)
tokenContract.balanceOf(owner: ENV.chris)

