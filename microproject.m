clear;
clc;

config_fname = 'conf.json';                                                                    %filename in JSON 
config_fid = fopen(config_fname);                                                              %opening the file
config_raw = fread(config_fid,inf);                                                            %reading the contents
config_str = char(config_raw');                                                                %transformation
fclose(config_fid);                                                                            %closing the file
d = jsondecode(config_str);                                                                    %using the jsondecode function to parse JSON from string


protocol_1_name=d.protocols(1).protocol_name;                                                  %get the name of the first protocol in JSON
protocol_2_name=d.protocols(2).protocol_name;                                                  %get the name of the second protocol in JSON

ID_of_UART_protocol=0;
ID_of_USB_protocol=0;


%check if the required two protocols (UART and USB) is exist in JSON

if strcmp(protocol_1_name,'UART') && strcmp(protocol_2_name,'USB') 
    ID_of_UART_protocol=1;
    ID_of_USB_protocol=2;
    
elseif  strcmp(protocol_1_name,'USB') && strcmp(protocol_2_name,'UART') 
        ID_of_UART_protocol=2;
        ID_of_USB_protocol=1;
        
    else
            disp(string('error'))
            
end
    
if (ID_of_UART_protocol ~= 0) && (ID_of_USB_protocol ~= 0)

%get the parameter of UART protocol from JSON
UartDataBits=d.protocols(ID_of_UART_protocol).parameters.data_bits;
UartStopBits=d.protocols(ID_of_UART_protocol).parameters.stop_bits;
UartParity=d.protocols(ID_of_UART_protocol).parameters.parity;
UartBitDuration=d.protocols(ID_of_UART_protocol).parameters.bit_duration;


%get the parameter of USB protocol from JSON
UsbSyncPattern=d.protocols(ID_of_USB_protocol).parameters.sync_pattern;
UsbPid=d.protocols(ID_of_USB_protocol).parameters.pid;
UsbDestAddress=d.protocols(ID_of_USB_protocol).parameters.dest_address;
UsbPayload=d.protocols(ID_of_USB_protocol).parameters.payload;
UsbBitDuration=d.protocols(ID_of_USB_protocol).parameters.bit_duration;


%extract the input data to be transimtted later
filename = 'inputdata.txt'; 
file_id = fopen(filename); 
raw1 = fread(file_id,inf);  
fclose(file_id); 
raw1bi = de2bi(raw1,UartDataBits,'left-msb');

UartTotalDataSize = UART (UartDataBits,UartStopBits,UartParity,UartBitDuration,raw1);
UsbTotalDataSize = USB(UsbSyncPattern,UsbDestAddress,UsbPayload,UsbBitDuration,raw1);
end

%%%%%%%%%%%%%%%checking the bit duration in the 2 protocols%%%%%%
 if(UartBitDuration == UsbBitDuration)
   
%%%%%%%%%%%%caculating the requaired output%%%%%%
   UART_total_time_to_transmit = UartTotalDataSize * UartBitDuration
   USB_total_time_to_transmit =  UsbTotalDataSize * UsbBitDuration
   input_total_size = size(raw1bi,1)* size(raw1bi,2)
   efficiency_UART = (input_total_size / UartTotalDataSize)
   efficiency_USB = (input_total_size / UsbTotalDataSize)
   overhead_UART = 1 - efficiency_UART
   overhead_USB = 1- efficiency_USB
   
   %%%%%%%save the output in JSON file%%%%%%%%%%%%%%
   
  protocols= struct('protocol_name',[],'output',[]);
   
  O.protocols(1).protocol_name='UART';
  O.protocols(1).output.total_tx_time=UART_total_time_to_transmit;
  O.protocols(1).output.overhead=overhead_UART;
  O.protocols(1).output.efficiency=efficiency_UART;
  
  O.protocols(2).protocol_name='USB';
  O.protocols(2).output.total_tx_time=USB_total_time_to_transmit;
  O.protocols(2).output.overhead=overhead_USB;
  O.protocols(2).output.efficiency=efficiency_USB;
  
 OEncoded = jsonencode(O);
 fid = fopen('output.json', 'w');
 fprintf(fid, '%s', OEncoded);
 fclose(fid);
 
 %%%%%%plotting the increasing of the outputs versus the input file size%%%%%
 
 UartTimeArr=zeros(1,5);
 UsbTimeArr=zeros(1,5);
 InputArr=zeros(1,5);
 UartOHArr=zeros(1,5);
 UsbOHArr=zeros(1,5);
 for f=1:5
     filename1 = strcat(int2str(f),'.txt');
     file_id1 = fopen(filename1); 
     raw2 = fread(file_id1,inf);
     raw2bi = de2bi(raw2,UartDataBits,'left-msb');
     
     input_total_size1 = size(raw2bi,1)* size(raw2bi,2);
     InputArr(1,f)=input_total_size1;
     
     UartTotalDataSize1 = UART (UartDataBits,UartStopBits,UartParity,UartBitDuration,raw2);
     UsbTotalDataSize1 = USB(UsbSyncPattern,UsbDestAddress,UsbPayload,UsbBitDuration,raw2);
     
   UART_total_time_to_transmit1 = UartTotalDataSize1 * UartBitDuration;
   USB_total_time_to_transmit1 =  UsbTotalDataSize1 * UsbBitDuration;
   efficiency_UART1 = (input_total_size1 / UartTotalDataSize1);
   efficiency_USB1 = (input_total_size1 / UsbTotalDataSize1);
   overhead_UART1 = 1 - efficiency_UART1;
   overhead_USB1 = 1- efficiency_USB1;
   
     UartTimeArr(1,f)= UART_total_time_to_transmit1
     UsbTimeArr(1,f)= USB_total_time_to_transmit1
     
     UartOHArr(1,f)= overhead_UART1
     UsbOHArr(1,f) = overhead_USB1
     
     
 end
 
 figure;
subplot(2,2,1)
plot(InputArr,UartTimeArr)
title('increase of the transmission time of UART versus the file size');
subplot(2,2,2)
plot(InputArr,UsbTimeArr)
title('increase of the transmission time of USB versus the file size');
subplot(2,2,3)
plot(InputArr,UartOHArr)
title('increase of the over head percentage of UART versus the file size');
subplot(2,2,4)
plot(InputArr,UsbOHArr)
title('increase of the over head percentage of USB versus the file size');

 end
 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% code of UART protocol
function[UART_total_data_size]= UART (UART_data_bits,UART_stop_bits,UART_parity,UART_bit_duration,raw)

uart_binary = de2bi(raw,UART_data_bits,'left-msb');                                      %convert the data from decimal to binary
A=fliplr(uart_binary);
uart_input_data=reshape(A,[],UART_data_bits);

uart_size_of_input_data=size(uart_input_data,1);                                         %calculate the size of the input data


%construct the packet
uart_start_bit=false(1);                                                                 %the Idle is 1, so the start bit is going to be 0
uart_stop_bit=transpose(true(UART_stop_bits,1));                                                    %stop bit
UART_total_data_size=0;


for num_packets=1:uart_size_of_input_data
    
uart_parity_bit=0;         uart_ones=0; 
    
uart_data_to_be_sent=uart_input_data(num_packets,:);                                     %get the data from the input_data

                                                                                         %the default of the parity is none
if ~strcmp(UART_parity,'none')                                            
    for i=1:UART_data_bits                                                               %calculate the number of ones
        if uart_data_to_be_sent(i)==1
            uart_ones=uart_ones+1;
        end
    end   
        if strcmp(UART_parity,'odd')                                                     %check if odd parity
            if rem(uart_ones,2)==0
                uart_parity_bit=true(1);
            else
                uart_parity_bit=false(1);
            end
            
        elseif strcmp(UART_parity,'even')                                                %check if even parity
                 if rem(uart_ones,2)==0
                    uart_parity_bit=false(1);
                else
                    uart_parity_bit=true(1);
                end
        end
end

if strcmp(UART_parity,'none')
     uart_packet=cat(2,uart_start_bit,uart_data_to_be_sent,uart_stop_bit);                    %the packet to be sent if parity is none
else
    uart_packet=cat(2,uart_start_bit,uart_data_to_be_sent,uart_parity_bit,uart_stop_bit);     %the packet to be sent with parity
end

 UART_total_data_size=  UART_total_data_size + length(uart_packet);

if (num_packets==1)
    UART_data_to_plot = uart_packet;
end
 if (num_packets==2)    
UART_data_to_plot=cat(2,UART_data_to_plot,uart_packet);
end

end

%%%plotting the first 2 bytes of the output%%%
total_time= UART_bit_duration * length(UART_data_to_plot);
t=0:UART_bit_duration:total_time;
subplot(3,1,1)
stairs(t,[UART_data_to_plot,UART_data_to_plot(end)]);
grid;
title('first 2 bytes in the UART protocol');
set(gca,'ylim',[-0.5 1.5])
set(gca,'xlim',[0 total_time])
set(gca,'XTick',[0:UART_bit_duration:total_time])

end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% code of USB protocol
function[USB_total_data_size]= USB(USB_sync_pattern,USB_dest_address,USB_payload,USB_bit_duration,raw)

usb_binary = de2bi(raw,8,'left-msb');                                      %convert the data from decimal to binary
usb_input_data=fliplr(usb_binary);

usb_sync = USB_sync_pattern-'0';                                           %the sync is converted to binary (it is always 00000001) 
 
                                                                           %the packet ID is 8 bits (4 bits ID + 4 bits inverted)
 PID_vector=0:15;
 PID=fliplr(de2bi(PID_vector,4,'left-msb'));                               %PID 
 PID_inverse=not(PID);                                                     %PID inverted
 PID_concat=cat(2,PID,PID_inverse);                                        %PID concatenated

usb_address = fliplr(USB_dest_address-'0');                                %the address is converted to binary

usb_input_data_size=size(usb_input_data,1);                                %check the size of data




%construct the packet
ID_counter=1;
usb_data_begin=1;
usb_data_end=USB_payload;

%check how many data packets can be sent
num_input_data=fix(usb_input_data_size/USB_payload);
remainder=rem(usb_input_data_size,USB_payload);                            %if the remainder not equal to zero that means: there is a few data in the input file that no. of bytes < USB_payload 


if remainder ~= 0
    num_packets=num_input_data+1;
else
    num_packets=num_input_data;
end

USB_total_data_size=0;

for I=1:num_packets
    
     if rem(ID_counter,16)==0
            ID_counter=1;
     end
    
     if I==num_packets                                                     %check if we reached that part of the data input < USB_payload
         data_input=usb_input_data(usb_data_begin:usb_input_data_size,:);
        
     else
        data_input= usb_input_data(usb_data_begin:usb_data_end,:);
     end

    usb_data_packet=reshape(transpose(data_input),1,[]);
    usb_PID= PID_concat(ID_counter,:);
    usb_packet=cat(2,usb_sync,usb_PID,usb_address,usb_data_packet);        %the packet before doing the bit stuffing

    
    
    %%%%%%%%Bit stuffing%%%%%%%%
    
    PacketSize=length(usb_packet); %declare it as a variable as it changes during the bit stuffing operations
    b =(0)';         %stuffed bit

for i=1:PacketSize
  
        if usb_packet(1,i)==1 && usb_packet(1,i+1)==1 && usb_packet(1,i+2)==1 && usb_packet(1,i+3)==1 && usb_packet(1,i+4)==1 && usb_packet(1,i+5)==1 %check id there's 6ones in a sequence 
         usb_packet = [usb_packet(:,1:i+5) b usb_packet(:,i+6:PacketSize)] ;
         PacketSize=PacketSize+1; %put zero in the middle
        end

end

USB_total_data_size = USB_total_data_size + length(usb_packet); 

    %%%%%%%%NRZI%%%%%%%%
    initial_state=1; %idle state
   final_usb_packet=zeros(1,PacketSize);  %empty final packet to save the NRZI
       
   %handling the first bit
        if usb_packet(1,1)==0
           final_usb_packet(1,1)=~(initial_state);
        end 
        if usb_packet(1,1)==1
           final_usb_packet(1,1)=(initial_state);
        end
        
    for i=2:PacketSize  %loop for the rest of packet
        
        if usb_packet(1,i)==0
           final_usb_packet(1,i)=~(final_usb_packet(1,i-1));
        end 
        if usb_packet(1,i)==1
           final_usb_packet(1,i)=(final_usb_packet(1,i-1));
        end
    end
    
    
    
    %%%%%%%%make a diffrential output%%%%%%%%
    Dplus=final_usb_packet;
    Dminus=not(final_usb_packet);
    
    
    
    %%%%%%%%EOP%%%%%%%%
    EOP=false(1);
    Dplus=cat(2,Dplus,EOP);
    Dminus=cat(2,Dminus,EOP);
    
    
    %%%%%%increasing the counter%%%%%%
    ID_counter=ID_counter+1;
    usb_data_begin=usb_data_begin+USB_payload;
    usb_data_end=usb_data_end+USB_payload;
    
    
 if(I==1)
    Data_plus_to_plot = Dplus;
    Data_minus_to_plot= Dminus; 
 end
 if(I==2)    
Data_plus_to_plot = cat(2,Data_plus_to_plot,Dplus);
Data_minus_to_plot = cat(2,Data_minus_to_plot,Dminus);
end
        
end


%%%%%%ploting the first 2 packets%%%%%%
  
 %%%%plotting D+ of the output%%%%%%   
total_time= USB_bit_duration * length(Data_plus_to_plot);
t=0:USB_bit_duration:total_time;
subplot(3,1,2)
stairs(t,[Data_plus_to_plot,Data_plus_to_plot(end)]);
grid;
title('first 2 packtes of USB protocol D+');
set(gca,'ylim',[-0.5 1.5])
set(gca,'xlim',[0 total_time])
set(gca,'XTick',[0:USB_bit_duration:total_time])


%%%%plotting D- of the output%%%%%
total_time= USB_bit_duration * length(Data_minus_to_plot);
t=0:USB_bit_duration:total_time;
subplot(3,1,3)
stairs(t,[Data_minus_to_plot,Data_minus_to_plot(end)]);
grid;
title('first 2 packtes of USB protocol D-');
set(gca,'ylim',[-0.5 1.5])
set(gca,'xlim',[0 total_time])
set(gca,'XTick',[0:USB_bit_duration:total_time])
end



 
