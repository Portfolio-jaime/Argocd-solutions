# ArgoCD Components Performance Report
Generated: Mon Jul 28 16:35:39 -05 2025

## Component Status Overview

### argocd-server

**Pod Status:**
```
NAME                             READY   STATUS    RESTARTS   AGE
argocd-server-7659b858fd-f4ccc   1/1     Running   0          3d1h
argocd-server-7659b858fd-p24dw   1/1     Running   0          3d1h
argocd-server-7659b858fd-pnrtv   1/1     Running   0          3d1h
argocd-server-7659b858fd-pvsms   1/1     Running   0          3d1h
argocd-server-7659b858fd-zpdjd   1/1     Running   0          3d1h
```

**Resource Usage:**
```
NAME                             CPU(cores)   MEMORY(bytes)   
argocd-server-7659b858fd-f4ccc   5m           83Mi            
argocd-server-7659b858fd-p24dw   3m           86Mi            
argocd-server-7659b858fd-pnrtv   3m           80Mi            
argocd-server-7659b858fd-pvsms   2m           81Mi            
argocd-server-7659b858fd-zpdjd   3m           84Mi            
```

### argocd-application-controller

**Pod Status:**
```
NAME                              READY   STATUS    RESTARTS   AGE
argocd-application-controller-0   1/1     Running   0          3d1h
```

**Resource Usage:**
```
NAME                              CPU(cores)   MEMORY(bytes)   
argocd-application-controller-0   1058m        638Mi           
```

### argocd-repo-server

**Pod Status:**
```
NAME                                  READY   STATUS    RESTARTS   AGE
argocd-repo-server-78c85657d5-gl2px   1/1     Running   0          4m28s
argocd-repo-server-78c85657d5-gx9nw   1/1     Running   0          3h48m
argocd-repo-server-78c85657d5-rp6h6   1/1     Running   0          5m28s
argocd-repo-server-78c85657d5-swl9c   1/1     Running   0          5m28s
argocd-repo-server-78c85657d5-xht5d   1/1     Running   0          3d1h
```

**Resource Usage:**
```
NAME                                  CPU(cores)   MEMORY(bytes)   
argocd-repo-server-78c85657d5-gl2px   21m          65Mi            
argocd-repo-server-78c85657d5-gx9nw   113m         191Mi           
argocd-repo-server-78c85657d5-rp6h6   77m          82Mi            
argocd-repo-server-78c85657d5-swl9c   18m          69Mi            
argocd-repo-server-78c85657d5-xht5d   120m         85Mi            
```

### argocd-redis

**Pod Status:**
```
```

**Resource Usage:**
```
```

