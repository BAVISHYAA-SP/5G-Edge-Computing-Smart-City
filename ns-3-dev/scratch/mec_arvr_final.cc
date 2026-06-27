#include "ns3/core-module.h"
#include "ns3/network-module.h"
#include "ns3/internet-module.h"
#include "ns3/point-to-point-module.h"
#include "ns3/applications-module.h"
#include "ns3/flow-monitor-module.h"
#include "ns3/netanim-module.h"
#include "ns3/mobility-module.h"

#include <fstream>
#include <iomanip>

using namespace ns3;

NS_LOG_COMPONENT_DEFINE("MecArVrFinal");

int
main(int argc, char *argv[])
{
    // -----------------------------------------------------------------------
    // 1. Simulation parameters (overridable from command line)
    // -----------------------------------------------------------------------
    double simTime       = 10.0;     // seconds
    uint32_t packetSize   = 1200;     // bytes (typical AR/VR frame chunk)
    std::string dataRate  = "20Mbps"; // AR/VR application data rate
    bool enablePcap        = false;
    bool enableNetAnim     = true;

    CommandLine cmd;
    cmd.AddValue("simTime", "Total simulation time (s)", simTime);
    cmd.AddValue("packetSize", "UDP payload size (bytes)", packetSize);
    cmd.AddValue("dataRate", "Application data rate", dataRate);
    cmd.AddValue("enablePcap", "Enable pcap tracing", enablePcap);
    cmd.AddValue("enableNetAnim", "Enable NetAnim XML output", enableNetAnim);
    cmd.Parse(argc, argv);

    Time::SetResolution(Time::NS);

    // -----------------------------------------------------------------------
    // 2. Create nodes
    // -----------------------------------------------------------------------
    NodeContainer ueNode;       ueNode.Create(1);     // AR/VR User Equipment
    NodeContainer gnbNode;      gnbNode.Create(1);    // 5G Base Station (gNB)
    NodeContainer mecNode;      mecNode.Create(1);    // MEC Server (edge)
    NodeContainer cloudRelay;   cloudRelay.Create(1);  // Backhaul relay hop (models distance to cloud)
    NodeContainer cloudNode;    cloudNode.Create(1);    // Cloud Server (core/data center)

    // -----------------------------------------------------------------------
    // 3. Point-to-Point links
    // -----------------------------------------------------------------------

    // UE <-> gNB : radio access hop, modeled as very low latency, modest rate
    PointToPointHelper ueGnbLink;
    ueGnbLink.SetDeviceAttribute("DataRate", StringValue("100Mbps"));
    ueGnbLink.SetChannelAttribute("Delay", StringValue("1ms"));

    // gNB <-> MEC : MEC is physically co-located / near the base station
    PointToPointHelper gnbMecLink;
    gnbMecLink.SetDeviceAttribute("DataRate", StringValue("1Gbps"));
    gnbMecLink.SetChannelAttribute("Delay", StringValue("1ms"));

    // gNB <-> Cloud relay : backhaul link (the "distance" to the core network)
    PointToPointHelper gnbRelayLink;
    gnbRelayLink.SetDeviceAttribute("DataRate", StringValue("500Mbps"));
    gnbRelayLink.SetChannelAttribute("Delay", StringValue("20ms"));

    // Relay <-> Cloud : final hop into the data center
    PointToPointHelper relayCloudLink;
    relayCloudLink.SetDeviceAttribute("DataRate", StringValue("500Mbps"));
    relayCloudLink.SetChannelAttribute("Delay", StringValue("15ms"));

    NetDeviceContainer ueGnbDevices       = ueGnbLink.Install(ueNode.Get(0), gnbNode.Get(0));
    NetDeviceContainer gnbMecDevices      = gnbMecLink.Install(gnbNode.Get(0), mecNode.Get(0));
    NetDeviceContainer gnbRelayDevices    = gnbRelayLink.Install(gnbNode.Get(0), cloudRelay.Get(0));
    NetDeviceContainer relayCloudDevices  = relayCloudLink.Install(cloudRelay.Get(0), cloudNode.Get(0));

    // -----------------------------------------------------------------------
    // 4. Internet stack + addressing
    // -----------------------------------------------------------------------
    InternetStackHelper stack;
    stack.Install(ueNode);
    stack.Install(gnbNode);
    stack.Install(mecNode);
    stack.Install(cloudRelay);
    stack.Install(cloudNode);

    Ipv4AddressHelper address;

    address.SetBase("10.1.1.0", "255.255.255.0");
    Ipv4InterfaceContainer ueGnbIf = address.Assign(ueGnbDevices);

    address.SetBase("10.1.2.0", "255.255.255.0");
    Ipv4InterfaceContainer gnbMecIf = address.Assign(gnbMecDevices);

    address.SetBase("10.1.3.0", "255.255.255.0");
    Ipv4InterfaceContainer gnbRelayIf = address.Assign(gnbRelayDevices);

    address.SetBase("10.1.4.0", "255.255.255.0");
    Ipv4InterfaceContainer relayCloudIf = address.Assign(relayCloudDevices);

    // Enable global routing since this is a multi-hop topology (gNB -> relay -> cloud)
    Ipv4GlobalRoutingHelper::PopulateRoutingTables();

    // -----------------------------------------------------------------------
    // 5. Applications
    //
    //    Two independent UDP flows from the SAME UE:
    //      Flow A: UE -> MEC server   (edge processing path)
    //      Flow B: UE -> Cloud server (cloud processing path)
    //
    //    Both run concurrently so FlowMonitor captures a fair, identical-
    //    traffic-pattern comparison between the two paths.
    // -----------------------------------------------------------------------
    uint16_t mecPort   = 5000;
    uint16_t cloudPort = 6000;

    // --- MEC path: server on MEC node ---
    UdpServerHelper mecServer(mecPort);
    ApplicationContainer mecServerApp = mecServer.Install(mecNode.Get(0));
    mecServerApp.Start(Seconds(0.0));
    mecServerApp.Stop(Seconds(simTime + 1.0));

    UdpClientHelper mecClient(gnbMecIf.GetAddress(1), mecPort); // MEC server's IP
    mecClient.SetAttribute("MaxPackets", UintegerValue(4294967295u));
    mecClient.SetAttribute("Interval", TimeValue(Seconds((packetSize * 8.0) / (20.0 * 1e6)))); // paced to ~20Mbps
    mecClient.SetAttribute("PacketSize", UintegerValue(packetSize));
    ApplicationContainer mecClientApp = mecClient.Install(ueNode.Get(0));
    mecClientApp.Start(Seconds(1.0));
    mecClientApp.Stop(Seconds(simTime));

    // --- Cloud path: server on Cloud node ---
    UdpServerHelper cloudServer(cloudPort);
    ApplicationContainer cloudServerApp = cloudServer.Install(cloudNode.Get(0));
    cloudServerApp.Start(Seconds(0.0));
    cloudServerApp.Stop(Seconds(simTime + 1.0));

    UdpClientHelper cloudClient(relayCloudIf.GetAddress(1), cloudPort); // Cloud server's IP
    cloudClient.SetAttribute("MaxPackets", UintegerValue(4294967295u));
    cloudClient.SetAttribute("Interval", TimeValue(Seconds((packetSize * 8.0) / (20.0 * 1e6))));
    cloudClient.SetAttribute("PacketSize", UintegerValue(packetSize));
    ApplicationContainer cloudClientApp = cloudClient.Install(ueNode.Get(0));
    cloudClientApp.Start(Seconds(1.0));
    cloudClientApp.Stop(Seconds(simTime));

    // -----------------------------------------------------------------------
    // 6. Mobility (positions only — needed for NetAnim layout)
    // -----------------------------------------------------------------------
    MobilityHelper mobility;
    Ptr<ListPositionAllocator> positionAlloc = CreateObject<ListPositionAllocator>();
    positionAlloc->Add(Vector(0.0, 30.0, 0.0));    // UE
    positionAlloc->Add(Vector(40.0, 30.0, 0.0));   // gNB
    positionAlloc->Add(Vector(80.0, 10.0, 0.0));   // MEC (near gNB)
    positionAlloc->Add(Vector(80.0, 50.0, 0.0));   // Cloud relay (backhaul hop)
    positionAlloc->Add(Vector(140.0, 50.0, 0.0));  // Cloud (far away)
    mobility.SetPositionAllocator(positionAlloc);
    mobility.SetMobilityModel("ns3::ConstantPositionMobilityModel");
    mobility.Install(ueNode);
    mobility.Install(gnbNode);
    mobility.Install(mecNode);
    mobility.Install(cloudRelay);
    mobility.Install(cloudNode);

    // -----------------------------------------------------------------------
    // 7. Optional pcap tracing
    // -----------------------------------------------------------------------
    if (enablePcap)
    {
        ueGnbLink.EnablePcapAll("mec_arvr_ue_gnb");
        gnbMecLink.EnablePcapAll("mec_arvr_gnb_mec");
        gnbRelayLink.EnablePcapAll("mec_arvr_gnb_relay");
        relayCloudLink.EnablePcapAll("mec_arvr_relay_cloud");
    }

    // -----------------------------------------------------------------------
    // 8. FlowMonitor
    // -----------------------------------------------------------------------
    FlowMonitorHelper flowmonHelper;
    Ptr<FlowMonitor> monitor = flowmonHelper.InstallAll();

    // -----------------------------------------------------------------------
    // 9. NetAnim
    // -----------------------------------------------------------------------
    AnimationInterface *anim = nullptr;
    if (enableNetAnim)
    {
        anim = new AnimationInterface("mec_arvr_final.xml");
        anim->SetConstantPosition(ueNode.Get(0), 0.0, 30.0);
        anim->SetConstantPosition(gnbNode.Get(0), 40.0, 30.0);
        anim->SetConstantPosition(mecNode.Get(0), 80.0, 10.0);
        anim->SetConstantPosition(cloudRelay.Get(0), 80.0, 50.0);
        anim->SetConstantPosition(cloudNode.Get(0), 140.0, 50.0);

        anim->UpdateNodeDescription(ueNode.Get(0), "AR/VR UE");
        anim->UpdateNodeDescription(gnbNode.Get(0), "gNB (5G Base Station)");
        anim->UpdateNodeDescription(mecNode.Get(0), "MEC Server");
        anim->UpdateNodeDescription(cloudRelay.Get(0), "Backhaul Relay");
        anim->UpdateNodeDescription(cloudNode.Get(0), "Cloud Server");

        anim->UpdateNodeColor(ueNode.Get(0), 0, 0, 255);
        anim->UpdateNodeColor(gnbNode.Get(0), 0, 200, 0);
        anim->UpdateNodeColor(mecNode.Get(0), 255, 165, 0);
        anim->UpdateNodeColor(cloudRelay.Get(0), 150, 150, 150);
        anim->UpdateNodeColor(cloudNode.Get(0), 255, 0, 0);

        anim->EnablePacketMetadata(true);
    }

    // -----------------------------------------------------------------------
    // 10. Run simulation
    // -----------------------------------------------------------------------
    Simulator::Stop(Seconds(simTime + 1.0));
    Simulator::Run();

    // -----------------------------------------------------------------------
    // 11. Serialize FlowMonitor results to XML (for reference / debugging)
    // -----------------------------------------------------------------------
    monitor->CheckForLostPackets();
    monitor->SerializeToXmlFile("flowmon.xml", true, true);

    // -----------------------------------------------------------------------
    // 12. Write a clean, flat CSV summary for Python/MATLAB
    //     (this is the file analysis.py and mec_analysis.m will read)
    // -----------------------------------------------------------------------
    Ptr<Ipv4FlowClassifier> classifier =
        DynamicCast<Ipv4FlowClassifier>(flowmonHelper.GetClassifier());
    FlowMonitor::FlowStatsContainer stats = monitor->GetFlowStats();

    std::ofstream csv("results_summary.csv");
    csv << "flow_id,path,src,dst,tx_packets,rx_packets,lost_packets,"
        << "avg_delay_ms,throughput_mbps,packet_loss_percent\n";

    for (auto const &entry : stats)
    {
        FlowId flowId = entry.first;
        FlowMonitor::FlowStats fs = entry.second;
        Ipv4FlowClassifier::FiveTuple t = classifier->FindFlow(flowId);

        // Classify the flow as MEC or CLOUD path based on destination port
        std::string path = "UNKNOWN";
        if (t.destinationPort == mecPort)   path = "MEC";
        if (t.destinationPort == cloudPort) path = "CLOUD";

        double avgDelayMs = 0.0;
        if (fs.rxPackets > 0)
        {
            avgDelayMs = (fs.delaySum.GetSeconds() / fs.rxPackets) * 1000.0;
        }

        double throughputMbps = 0.0;
        if (fs.timeLastRxPacket > fs.timeFirstTxPacket)
        {
            throughputMbps = (fs.rxBytes * 8.0) /
                              (fs.timeLastRxPacket.GetSeconds() - fs.timeFirstTxPacket.GetSeconds()) /
                              1e6;
        }

        uint64_t lost = fs.txPackets - fs.rxPackets;
        double lossPercent = (fs.txPackets > 0)
                                  ? (100.0 * lost / fs.txPackets)
                                  : 0.0;

        csv << flowId << ","
            << path << ","
            << t.sourceAddress << ","
            << t.destinationAddress << ","
            << fs.txPackets << ","
            << fs.rxPackets << ","
            << lost << ","
            << std::fixed << std::setprecision(4) << avgDelayMs << ","
            << std::fixed << std::setprecision(4) << throughputMbps << ","
            << std::fixed << std::setprecision(4) << lossPercent
            << "\n";
    }
    csv.close();

    std::cout << "\n=== Simulation complete ===\n";
    std::cout << "  flowmon.xml          -> detailed FlowMonitor XML\n";
    std::cout << "  mec_arvr_final.xml   -> NetAnim animation\n";
    std::cout << "  results_summary.csv  -> flat CSV for Python/MATLAB\n\n";

    Simulator::Destroy();
    if (anim) delete anim;

    return 0;
}
