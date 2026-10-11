import NFCCore
import NFCTransport

package actor ScriptedCardTransport {
    package private(set) var sentCommands: [CommandAPDU] = []

    private var responses: [Result<ResponseAPDU, TransportError>]

    package init(responses: [Result<ResponseAPDU, TransportError>]) {
        self.responses = responses
    }
}

extension ScriptedCardTransport: CardTransport {
    package func transmit(_ command: CommandAPDU) async throws(TransportError) -> ResponseAPDU {
        sentCommands.append(command)

        guard !responses.isEmpty else {
            throw .connectionLost
        }

        return try responses.removeFirst().get()
    }
}
