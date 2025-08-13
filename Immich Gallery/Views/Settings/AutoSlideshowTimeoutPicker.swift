import SwiftUI

struct AutoSlideshowTimeoutPicker: View {
    @Binding var timeout: Int
    let options: [Int] = [0, 1, 3, 5, 10, 15, 30, 60] // 0 = Off
    
    var body: some View {
        Picker("Auto-Start After", selection: $timeout) {
            ForEach(options, id: \.self) { value in
                if value == 0 {
                    Text("Off").tag(0)
                } else {
                    Text("\(value) min").tag(value)
                }
            }
        }
        .pickerStyle(.menu)
        .frame(width: 300, alignment: .trailing)
    }
}


#Preview {
    @Previewable
    @State var timeout = 10
    return AutoSlideshowTimeoutPicker(timeout: $timeout)
}
