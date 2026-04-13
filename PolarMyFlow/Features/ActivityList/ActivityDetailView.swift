import SwiftUI

struct ActivityDetailView: View {
    let activity: Activity
    @State private var viewModel: ActivityDetailViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                List {
                    Section("Overview") {
                        LabeledContent("Date", value: vm.dateString)
                        LabeledContent("Duration", value: vm.durationString)
                        LabeledContent("Distance", value: vm.distanceString)
                        LabeledContent("Avg Pace", value: vm.paceString)
                    }
                    if vm.avgHRString != nil || vm.maxHRString != nil {
                        Section("Heart Rate") {
                            if let avg = vm.avgHRString {
                                LabeledContent("Average", value: avg)
                            }
                            if let max = vm.maxHRString {
                                LabeledContent("Maximum", value: max)
                            }
                        }
                    }
                    if vm.ascentString != nil || vm.descentString != nil {
                        Section("Elevation") {
                            if let asc = vm.ascentString {
                                LabeledContent("Ascent", value: asc)
                            }
                            if let desc = vm.descentString {
                                LabeledContent("Descent", value: desc)
                            }
                        }
                    }
                    if let cal = vm.caloriesString {
                        Section("Energy") {
                            LabeledContent("Calories", value: cal)
                        }
                    }
                }
                .navigationTitle(vm.title)
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .onAppear {
            viewModel = ActivityDetailViewModel(activity: activity)
        }
    }
}
