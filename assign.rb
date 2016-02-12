require 'acirb'
require 'highline/import'

# If run from a policy server or on a cron vlan assignments can be automated.
# Keep your discover EPG in a seperate tenant so as not to harm the healthscore of your primary tenant.
# EXAMPLE text file
# MAC                EPG     TAG
# 2C:54:2D:FE:EC:80	EXAMPLE	398
# returns an array of {:mac => mac, :epg => epg, :vlan => vlan}
def read_assignment_file(file)
  f = File.read(file)
  hash_array = []
  f.lines.each do |line|
    line = line.split
    hash = {}
    hash[:mac] = line.first
    hash[:epg] = line[1]
    hash[:vlan] = line.last
    hash_array << hash
  end
  return hash_array
end

# A path is drafted before pushed into the running configuration.
# Add important configuration items such as vlan, tagging, on-demand or immediate etc...
# Finally you specify the tDn or the topological DN of your path. This references the object in the fabric/pod/leaf location. 
# This script will grab this information from the endpoint discovered in the discover EPG. You shouldn't need to compile this data yourself.
#
# new_path = add_path(my_epg, 399, "topology/pod-1/paths-101/pathep-[eth1/33]")
# new_path.create(epg_name, vlan_number, path_tdn)
def add_path(epg, vlan, tdn)
  new_path = ACIrb::FvRsPathAtt.new(epg)
  new_path.instrImedcy = "immediate"
  new_path.tDn = tdn
  new_path.encap = "vlan-#{vlan}"
  new_path.mode = "untagged"
  return new_path
end

# Returns the EPG object path ACIrb::FvRsPathAtt which can be modified (Relative EPG path)
# Modifying this allows you to change a path from one EPG to another
#
# path = get_path(apic, epg_name, path_tdn)
def get_path(apic, epg, tdn)
  dnq = ACIrb::DnQuery.new(epg.dn)
  dnq.class_filter = 'fvRsPathAtt'
  dnq.query_target = 'children'
  pathatt = apic.query(dnq)
  p = pathatt.select { |p| p.tDn == tdn }
  return p.empty? ? nil : p.first
end

#Connect to the controller
host = "apic01.test.com"
apicurl = "https://#{host}"
username = "admin"
password = ask("Password:  ") { |q| q.echo = "*" }
apic = ACIrb::RestClient.new(url: apicurl, user: username, password: password)

#Identify all hosts in discovery EPG
discovery_endpoints = nil

dn = "uni/tn-PROD_LAB/ap-Core/epg-discovery"
dnq = ACIrb::DnQuery.new(dn)
dnq.class_filter = "fvCEp"      #<-- filter by client endpoints
dnq.query_target = 'subtree'
dnq.subtree = 'full'
discovery_endpoints = apic.query dnq

assignment_array = read_assignment_file("assignment_file.txt")

discovery_endpoints.each do |ep|
  #Match hosts found in the discover EPG to hosts listed in the policy file
  match = assignment_array.select { |a| a[:mac] == ep.mac }.first
  
  if match
    #Get endpoint object
    designated_epg = apic.lookupByDn("uni/tn-PROD_LAB/ap-Core/epg-#{match[:epg]}")
    
    #Get endpoint path object
    path = get_path(apic, ep.parent, ep.rscEpToPathEp.first.tDn)
    #Endpoitn path TDN used to create a new path.
    path_tdn = path.tDn
    #Delete the old path connecting the host to Discover
    path.destroy(apic)
    
    #Create the new path connecting the host to the assigned vlan.
    new_path = add_path(designated_epg, match[:vlan], path_tdn)
    new_path.create(apic)
  end
end