require 'acirb'

module Show_aci
  def endpoint(apic, host = nil)
    unless host
      endpoints = apic.lookupByClass('fvCEp', subtree: 'full')

      puts "%-15s %-20s %-50s %s %s" % ["IP", "MAC", "EPG", "IF", "ENCAP"]
      endpoints.each do |endpoint|
        ip = endpoint.attributes["ip"]
        mac = endpoint.attributes["mac"]
        epg = endpoint.parent.dn
        path = endpoint.rscEpToPathEp.first.attributes["tDn"]
        encap = endpoint.attributes["encap"]
        puts "%-15s %-20s %-50s %s %s" % [ip, mac, epg, path, encap]
      end
    else
      m = host.match(/\d+\.\d+\.\d+\.\d+/)
      cq = ACIrb::ClassQuery.new("fvCEp")
      cq.subtree = 'children'
      ep = nil
      if m
        m = m[0]
        cq.prop_filter = 'eq(fvCEp.ip,"%s")' % [m]
      else
        cq.prop_filter = 'eq(fvCEp.mac,"%s")' % [host]
      end
      endpoint = apic.query(cq).first
      dn = endpoint.attributes["dn"]
      ip = endpoint.attributes["ip"]
      mac = endpoint.attributes["mac"]
      epg = endpoint.parent.dn
      path = endpoint.rscEpToPathEp.first.attributes["tDn"]
      encap = endpoint.attributes["encap"]
      puts "%-20s %s" % ["DN:", dn]
      puts "%-20s %s" % ["IP:", ip]
      puts "%-20s %s" % ["MAC:", mac]      
      puts "%-20s %s" % ["VLAN:", encap]
      puts "%-20s %s" % ["EPG:", epg]
      puts "%-20s %s" % ["PATH:", path]
    end
  end
end