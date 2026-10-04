import NFCCore

package protocol CardTransport: Sendable {
    func transmit(_ command: CommandAPDU) async throws(TransportError) -> ResponseAPDU
}
