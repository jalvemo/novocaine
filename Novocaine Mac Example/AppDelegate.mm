#import "AppDelegate.h"

@implementation AppDelegate

@synthesize window = _window;

- (void)dealloc
{
    [super dealloc];
}

float sineOsc(float phase){
    return sin(phase * M_PI * 2);
}

float squareOsc(float phase){
    return signbit(phase);
}

float sawOsc(float phase){
    return phase;
}

struct Osc {
    float freq;
    float phase = 0;
};

static inline float freqFromNote(int note) {
    return 440.0 * pow(2,((double)note-69.0)/12.0);
}

Osc o1, o2, o3;
NSMutableArray *currentlyPlayingNotesInOrder = [NSMutableArray array];
NSMutableSet *currentlyPlayingNotes = [NSMutableSet set];

//    currentlyPlayingNotes = [[NSMutableSet init] alloc];
//    currentlyPlayingNotesInOrder = [[NSMutableArray init] alloc];


void playNote(int note) {
    Novocaine *audioManager = [Novocaine audioManager];
    o1.freq = freqFromNote(note);
    o2.freq = o1.freq + 1;
    o3.freq = freqFromNote(note - 12);
    
    
    float attack = 20000.0; // min 1 = instant
    __block float attackProgress = 0;
    
    float adsr = 0;
    adsr = 0;
    
    [audioManager setOutputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels)  {
        float samplingRate = audioManager.samplingRate;
        for (int i=0; i < numFrames; ++i) {
            
            if (attackProgress < 1){
                attackProgress = attackProgress + 1/attack;
            }
            
            float theta =attackProgress * (sawOsc(o1.phase) + sawOsc(o2.phase) + sawOsc(o3.phase)) / 3;
            
            for (int iChannel = 0; iChannel < numChannels; ++iChannel)
                data[i * numChannels + iChannel] = theta;
            
            o1.phase += 1.0 / (samplingRate / o1.freq);
            o2.phase += 1.0 / (samplingRate / o2.freq);
            o3.phase += 1.0 / (samplingRate / o3.freq);
            
            if (o1.phase > 1.0) o1.phase = -1;
            if (o2.phase > 1.0) o2.phase = -1;
            if (o3.phase > 1.0) o3.phase = -1;
        }
    }];
}                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           

void silence() {
    Novocaine *audioManager = [Novocaine audioManager];
    [audioManager setOutputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels)  {
        for (int i=0; i < numFrames; ++i)
            for (int iChannel = 0; iChannel < numChannels; ++iChannel)
                data[i*numChannels + iChannel] = 0;
    }];
}

void midiInputCallback (const MIDIPacketList *packetList, void *procRef, void *srcRef)
{
    const MIDIPacket *packet = packetList->packet;
    int message = packet->data[0];
    int note = packet->data[1];
    int velocity = packet->data[2];
    
    NSNumber *noteNumber = [NSNumber numberWithInt:note];
    //NSLog(@"%3i %3i %3i", message, note, velocity);
    
    if (message >= 128 && message <= 143) { // note off
        [currentlyPlayingNotes removeObject:noteNumber];
        
        // ta bort senaste noterna om de inte spelas längre
        while ([currentlyPlayingNotesInOrder count] > 0 && ![currentlyPlayingNotes containsObject:[currentlyPlayingNotesInOrder lastObject]]) {
                [currentlyPlayingNotesInOrder removeLastObject];
        }
        
        if ([currentlyPlayingNotesInOrder count] > 0) {
            playNote([[currentlyPlayingNotesInOrder lastObject] integerValue]);
        } else {
            silence();
        }
    }
    if (message >= 144 && message <= 159) { // note n
        [currentlyPlayingNotesInOrder addObject:noteNumber];
        [currentlyPlayingNotes addObject:noteNumber];
        playNote(note);
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    //set up midi input
    MIDIClientRef midiClient;
    MIDIEndpointRef src;
    
    OSStatus result;
    
    result = MIDIClientCreate(CFSTR("MIDI client"), NULL, NULL, &midiClient);
    if (result != noErr) {
        NSLog(@"Errore : %s - %s",
              GetMacOSStatusErrorString(result),
              GetMacOSStatusCommentString(result));
        return;
    }
    
    //note the use of "self" to send the reference to this document object
    result = MIDIDestinationCreate(midiClient, CFSTR("Porta virtuale"), midiInputCallback, self, &src);
    if (result != noErr ) {
        NSLog(@"Errore : %s - %s",
              GetMacOSStatusErrorString(result),
              GetMacOSStatusCommentString(result));
        return;
    }
    
    MIDIPortRef inputPort;
    //and again here
    result = MIDIInputPortCreate(midiClient, CFSTR("Input"), midiInputCallback, self, &inputPort);
    
    ItemCount numOfDevices = MIDIGetNumberOfDevices();
    
    for (int i = 0; i < numOfDevices; i++) {
        MIDIDeviceRef midiDevice = MIDIGetDevice(i);
        NSDictionary *midiProperties;
        
        MIDIObjectGetProperties(midiDevice, (CFPropertyListRef *)&midiProperties, YES);
        MIDIEndpointRef src = MIDIGetSource(i);
        MIDIPortConnectSource(inputPort, src, NULL);
    }
}

@end
