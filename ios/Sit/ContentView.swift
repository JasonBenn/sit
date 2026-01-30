import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            PromptFlowView()
                .navigationTitle("Sit")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
