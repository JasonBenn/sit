import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: WatchViewModel

    var body: some View {
        PromptFlowView()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(WatchViewModel())
    }
}
